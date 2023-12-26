# ------------------------COSMOSDBロギング用追加:start------------------------

# TODO:CosmosDB化
import os
import json
import jwt
import logging
import traceback
from quart import request
from opencensus.ext.azure.log_exporter import AzureLogHandler
from enum import Enum
from azure.cosmos import CosmosClient
from azure.identity import DefaultAzureCredential

# CosmosDB
endpoint = os.environ.get("AZURE_COSMOSDB_ENDPOINT")
database_name = os.environ.get("AZURE_COSMOSDB_DATABASE")
container_name = os.environ.get("AZURE_COSMOSDB_CONTAINER")
# CosmosDB Initialization
credential = DefaultAzureCredential()
database = CosmosClient(endpoint, credential).get_database_client(database_name)
container = database.get_container_client(container_name)

logger = logging.getLogger('same_hierarchy')

class ApproachType(Enum):
    Chat = "chat"
    Ask = "ask"
    Other="other"

def get_user_name(req: request):
    user_name = ""
    try:
        token = req.headers["X-MS-TOKEN-AAD-ID-TOKEN"]
        claim = jwt.decode(jwt=token, options={"verify_signature": False})
        user_name = claim["preferred_username"]
        write_chatlog(ApproachType.Other, user_name, 0, "claim", json.dumps(claim))
    except Exception:
        user_name = "anonymous"

    return user_name

def write_chatlog(approach: ApproachType, user_name: str, total_tokens: int, input: str, response: str, query: str=""):
    properties = {
        "approach" : approach.value,
        "user" : user_name, 
        "tokens" : total_tokens,
        "input" : input,  
        "response" : response
    }

    if query != "":
        properties["query"] = query
    container.create_item(body=properties, enable_automatic_id_generation=True)

def write_error(category: str, user_name: str, error: str):
    properties = {
        "category" : category, # "chat", "docsearch", "content"
        "user" : user_name,
        "error" : error
    }

    log_data = json.dumps(properties).encode('utf-8').decode('unicode-escape')
    traceback.print_exc()
    logger.error(log_data)
