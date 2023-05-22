import json
import requests
import logging
from pathlib import Path
import sys

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
    return cv2api_createGeneric('192.168.59.134', '/configuration/hosts/groups', authToken, jsonData)

def cv2api_createHostCategory(serverAddress: str, jsonData, authToken, customUri: str = "centreon", serverProto: str = "http"):
    return cv2api_createGeneric('192.168.59.134', '/configuration/hosts/categories', authToken, jsonData)

def cv2api_createHostSeverity(serverAddress: str, jsonData, authToken, customUri: str = "centreon", serverProto: str = "http"):
    return cv2api_createGeneric('192.168.59.134', '/configuration/hosts/severities', authToken, jsonData)

def cv2api_createServiceGroup(serverAddress: str, jsonData, authToken, customUri: str = "centreon", serverProto: str = "http"):
    return cv2api_createGeneric('192.168.59.134', '/configuration/services/groups', authToken, jsonData)

def cv2api_createServiceCategory(serverAddress: str, jsonData, authToken, customUri: str = "centreon", serverProto: str = "http"):
    return cv2api_createGeneric('192.168.59.134', '/configuration/services/categories', authToken, jsonData)

def cv2api_createServiceSeverity(serverAddress: str, jsonData, authToken, customUri: str = "centreon", serverProto: str = "http"):
    return cv2api_createGeneric('192.168.59.134', '/configuration/services/severities', authToken, jsonData)

def main():
    logging.debug('main() starting')
    logging.info("Authenticating")
    myToken = cv2api_authenticate('192.168.59.134')

    logging.info("Managing host groups")
    hg_data = json.loads(load_file(str(Path(__file__).parent.resolve()) + "/source_data/host_groups.json"))
    for hg in hg_data:
        #logging.debug(json.dumps(hg))
        cv2api_createHostGroup('192.168.59.134', hg, myToken)
    
    logging.info("Managing host categories")
    hc_data = json.loads(load_file(str(Path(__file__).parent.resolve()) + "/source_data/host_categories.json"))
    for hc in hc_data:
        cv2api_createHostCategory('192.168.59.134', hc, myToken)
    
    logging.info("Managing host severities")
    hs_data = json.loads(load_file(str(Path(__file__).parent.resolve()) + "/source_data/host_severities.json"))
    for hs in hs_data:
        cv2api_createHostSeverity('192.168.59.134', hs, myToken)

    logging.info("Managing service groups")
    hg_data = json.loads(load_file(str(Path(__file__).parent.resolve()) + "/source_data/service_groups.json"))
    for hg in hg_data:
        #logging.debug(json.dumps(hg))
        cv2api_createServiceGroup('192.168.59.134', hg, myToken)
    
    logging.info("Managing service categories")
    hc_data = json.loads(load_file(str(Path(__file__).parent.resolve()) + "/source_data/service_categories.json"))
    for hc in hc_data:
        cv2api_createServiceCategory('192.168.59.134', hc, myToken)
    
    logging.info("Managing service severities")
    hs_data = json.loads(load_file(str(Path(__file__).parent.resolve()) + "/source_data/service_severities.json"))
    for hs in hs_data:
        cv2api_createServiceSeverity('192.168.59.134', hs, myToken)

    logging.debug('main() ending')

logging.basicConfig(encoding='utf-8', level=logging.INFO, format='[%(asctime)s][%(levelname)s] %(message)s')
logging.info('Script starting')
main()
logging.info('Script ending')
