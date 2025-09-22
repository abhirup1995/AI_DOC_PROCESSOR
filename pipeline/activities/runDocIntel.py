import azure.durable_functions as df
import logging
from pipelineUtils.blob_functions import list_blobs, get_blob_content, write_to_blob
from pipelineUtils import get_month_date
# Libraries used in the future Document Processing client code
from azure.identity import DefaultAzureCredential
from azure.ai.documentintelligence import DocumentIntelligenceClient
from azure.ai.documentintelligence.models import AnalyzeResult, AnalyzeDocumentRequest
import base64
import json
import os
import requests

from configuration import Configuration
config = Configuration()

# Variables used by Document Processing client code
endpoint = config.get_value("AIMULTISERVICES_ENDPOINT") # Add the AI Services Endpoint value from Azure Function App settings

name = "runDocIntel"
bp = df.Blueprint()

def normalize_blob_name(container: str, raw_name: str) -> str:
    """Strip container prefix if included in the name."""
    if raw_name.startswith(container + "/"):
        return raw_name[len(container) + 1:]
    return raw_name

@bp.function_name(name)
@bp.activity_trigger(input_name="blobObj")
def extract_text_from_blob(blobObj: dict):
  logging.info(f"[runDocIntel] raw input type={type(blobObj)} preview={repr(blobObj)[:200]}")

  if isinstance(blobObj, str):
      try:
          blobObj = json.loads(blobObj)
      except Exception as e:
          raise TypeError(f"runDocIntel expected dict or JSON string; got str that failed JSON decode: {e}")
  if not isinstance(blobObj, dict):
      raise TypeError(f"runDocIntel expected dict; got {type(blobObj)}")

  try:
    
    client = DocumentIntelligenceClient(
        endpoint=endpoint, credential=config.credential
    )
    logging.info(f"BlobObj: {blobObj}")
    # 

    blob_name = normalize_blob_name(blobObj["container"],blobObj["name"])
    logging.info(f"Normalized Blob Name: {blob_name}")
    blob_content = get_blob_content(
        container_name=blobObj["container"],
        blob_path=blob_name
    )
    logging.info(f"Response status code: {blob_content}")

    
    logging.info(f"Starting analyze document: {blob_content[:100]}...")  # Log the first 50 bytes of the file for debugging}")
    poller = client.begin_analyze_document(
        # AnalyzeDocumentRequest Class: https://learn.microsoft.com/en-us/python/api/azure-ai-documentintelligence/azure.ai.documentintelligence.models.analyzedocumentrequest?view=azure-python
        "prebuilt-read", AnalyzeDocumentRequest(bytes_source=blob_content)
      )
    
    result: AnalyzeResult = poller.result()
    logging.info(f"Analyze document completed with status: {result}")
    if result.paragraphs:    
        paragraphs = "\n".join([paragraph.content for paragraph in result.paragraphs])            
    
    return paragraphs
      
  except Exception as e:
    logging.error(f"Error processing {blobObj}: {e}")
    return None
