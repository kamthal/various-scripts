import json
import requests
import logging
from pathlib import Path
import sys

def load_file(filePath):
    logging.debug('load_file() starting')

    fh = open(filePath, "r")
    file_content = fh.read()
    fh.close()

    logging.debug('load_file() ending')
    return(file_content)

def cv2api_authenticate(serverAddress: str, userName: str = "admin", userPassword: str = "centreon", customUri: str = "centreon", serverProto: str = "http") -> str:
    logging.debug("cv2api_authenticate() starting")

    endpointAuth = serverProto + "://" + serverAddress + "/" + customUri + "/api/latest/login"
    json_credentials = {
        "security": {
            "credentials": {
                "login": userName,
                "password": userPassword
            }
        }
    }
    response = requests.post(endpointAuth, json=json_credentials)
    body = json.loads(str(response.content.decode()))
    logging.debug("cv2api_authenticate() ending")
    return(str(body['security']['token']))

def load_file(filePath):
    fh = open(
        filePath,
        "r"
        )
    file_content = fh.read()
    fh.close()
    return(file_content)
    
def cv2api_createGeneric(serverAddress: str, endpointUrl, authToken, jsonData, customUri: str = "centreon", serverProto: str = "http"):
    logging.debug("cv2api_createGeneric() starting")
    post_headers = {"X-AUTH-TOKEN": authToken, "Accept": "text/json"}
    fullUrl = serverProto + "://" + serverAddress + "/" + customUri + '/api/latest' + endpointUrl
    response = requests.post(fullUrl, headers=post_headers, json=jsonData)
    body = json.loads(str(response.content.decode()))
    
    match str(response.status_code):
        case '200':
            logging.info("API call succeeded. Response: " + str(body))
        case '409':
            logging.warning("API call failed, object probably already exists. Response: " + str(body))
        case '400':
            logging.error("API call failed. Response: " + str(body))
    logging.debug("cv2api_createGeneric() ending")
    return(str(body))

def cv2api_createHostGroup(serverAddress: str, jsonData, authToken, customUri: str = "centreon", serverProto: str = "http"):
    return cv2api_createGeneric(serverAddress, '/configuration/hosts/groups', authToken, jsonData)

def cv2api_createHostCategory(serverAddress: str, jsonData, authToken, customUri: str = "centreon", serverProto: str = "http"):
    return cv2api_createGeneric(serverAddress, '/configuration/hosts/categories', authToken, jsonData)

def cv2api_createHostSeverity(serverAddress: str, jsonData, authToken, customUri: str = "centreon", serverProto: str = "http"):
    return cv2api_createGeneric(serverAddress, '/configuration/hosts/severities', authToken, jsonData)

def cv2api_createServiceGroup(serverAddress: str, jsonData, authToken, customUri: str = "centreon", serverProto: str = "http"):
    return cv2api_createGeneric(serverAddress, '/configuration/services/groups', authToken, jsonData)

def cv2api_createServiceCategory(serverAddress: str, jsonData, authToken, customUri: str = "centreon", serverProto: str = "http"):
    return cv2api_createGeneric(serverAddress, '/configuration/services/categories', authToken, jsonData)

def cv2api_createServiceSeverity(serverAddress: str, jsonData, authToken, customUri: str = "centreon", serverProto: str = "http"):
    return cv2api_createGeneric(serverAddress, '/configuration/services/severities', authToken, jsonData)

def main():
    logging.debug('main() starting')

    logging.info("Reading config file")
    config_data = json.loads(load_file(str(Path(__file__).parent.resolve()) + "/config.json"))
    centreonServer = config_data['centreonServer']
    centreonCustomUri = config_data['centreonCustomUri']
    centreonProto = config_data['centreonProto']
    centreonLogin = config_data['centreonLogin']
    centreonPassword = config_data['centreonPassword']

    logging.info("Authenticating")
    myToken = cv2api_authenticate(serverAddress=centreonServer, userName=centreonLogin, userPassword=centreonPassword, customUri=centreonCustomUri, serverProto=centreonProto)

    arrayOfObjs = json.loads(load_file(str(Path(__file__).parent.resolve()) + "/source_data/host_groups.json"))
    logging.info("Creating " + str(len(arrayOfObjs)) + " host groups")
    for obj in arrayOfObjs:
        #logging.debug(json.dumps(hg))
        cv2api_createHostGroup(centreonServer, obj, myToken)
    
    arrayOfObjs = json.loads(load_file(str(Path(__file__).parent.resolve()) + "/source_data/host_categories.json"))
    logging.info("Creating " + str(len(arrayOfObjs)) + " host categories")
    for obj in arrayOfObjs:
        cv2api_createHostCategory(centreonServer, obj, myToken)
    
    arrayOfObjs = json.loads(load_file(str(Path(__file__).parent.resolve()) + "/source_data/host_severities.json"))
    logging.info("Creating " + str(len(arrayOfObjs)) + " host severities")
    for obj in arrayOfObjs:
        cv2api_createHostSeverity(centreonServer, obj, myToken)

    arrayOfObjs = json.loads(load_file(str(Path(__file__).parent.resolve()) + "/source_data/service_groups.json"))
    logging.info("Creating " + str(len(arrayOfObjs)) + " service groups")
    for obj in arrayOfObjs:
        #logging.debug(json.dumps(hg))
        cv2api_createServiceGroup(centreonServer, obj, myToken)
    
    arrayOfObjs = json.loads(load_file(str(Path(__file__).parent.resolve()) + "/source_data/service_categories.json"))
    logging.info("Creating " + str(len(arrayOfObjs)) + " service categories")
    for obj in arrayOfObjs:
        cv2api_createServiceCategory(centreonServer, obj, myToken)
    
    arrayOfObjs = json.loads(load_file(str(Path(__file__).parent.resolve()) + "/source_data/service_severities.json"))
    logging.info("Creating " + str(len(arrayOfObjs)) + " service severities")
    for obj in arrayOfObjs:
        cv2api_createServiceSeverity(centreonServer, obj, myToken)

    logging.debug('main() ending')

logging.basicConfig(encoding='utf-8', level=logging.INFO, format='[%(asctime)s][%(levelname)s] %(message)s')
logging.info('Script starting')
main()
logging.info('Script ending')
