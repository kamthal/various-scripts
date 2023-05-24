import json
import requests
import logging
from pathlib import Path

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

def cv2api_getGeneric(serverAddress: str, endpointUrl, authToken, customUri: str = "centreon", serverProto: str = "http"):
    logging.debug("cv2api_getGeneric() starting")
    post_headers = {"X-AUTH-TOKEN": authToken, "Accept": "text/json"}
    fullUrl = serverProto + "://" + serverAddress + "/" + customUri + '/api/latest' + endpointUrl
    response = requests.get(fullUrl, headers=post_headers)
    body = json.loads(str(response.content.decode()))
    
    match str(response.status_code):
        case '200' | '201':
            logging.debug("API call succeeded. Response: " + str(body))
        case '409':
            logging.warning("API call failed. Response: " + str(body))
        case '400':
            logging.error("API call failed. Response: " + str(body))
    logging.debug("cv2api_getGeneric() ending")
    return(body)

def cv2api_getHostGroups(serverAddress: str, authToken: str, customUri: str = "centreon", serverProto: str = "http"):
    logging.debug('cv2api_getHostGroups() starting')
    body = cv2api_getGeneric(serverAddress, '/configuration/hosts/groups', authToken=authToken)
    logging.debug('cv2api_getHostGroups() starting')
    return(body)

def cv2api_getHostCategories(serverAddress: str, authToken: str, customUri: str = "centreon", serverProto: str = "http"):
    logging.debug('cv2api_getHostCategories() starting')
    body = cv2api_getGeneric(serverAddress, '/configuration/hosts/categories', authToken=authToken)
    logging.debug('cv2api_getHostCategories() starting')
    return(body)

def cv2api_getHostSeverities(serverAddress: str, authToken: str, customUri: str = "centreon", serverProto: str = "http"):
    logging.debug('cv2api_getHostSeverities() starting')
    body = cv2api_getGeneric(serverAddress, '/configuration/hosts/severities', authToken=authToken)
    logging.debug('cv2api_getHostSeverities() starting')
    return(body)

def cv2api_getServiceGroups(serverAddress: str, authToken: str, customUri: str = "centreon", serverProto: str = "http"):
    logging.debug('cv2api_getServiceGroup() starting')
    body = cv2api_getGeneric(serverAddress, '/configuration/services/groups', authToken=authToken)
    logging.debug('cv2api_getServiceGroup() starting')
    return(body)

def cv2api_getServiceCategories(serverAddress: str, authToken: str, customUri: str = "centreon", serverProto: str = "http"):
    logging.debug('cv2api_getServiceCategorie() starting')
    body = cv2api_getGeneric(serverAddress, '/configuration/services/categories', authToken=authToken)
    logging.debug('cv2api_getServiceCategorie() starting')
    return(body)

def cv2api_getServiceSeverities(serverAddress: str, authToken: str, customUri: str = "centreon", serverProto: str = "http"):
    logging.debug('cv2api_getServiceSeveritie() starting')
    body = cv2api_getGeneric(serverAddress, '/configuration/services/severities', authToken=authToken)
    logging.debug('cv2api_getServiceSeveritie() starting')
    return(body)

def cv2api_deleteGeneric(serverAddress: str, endpointUrl, authToken, idToDelete:int, customUri: str = "centreon", serverProto: str = "http"):
    logging.debug("cv2api_deleteGeneric() starting")
    post_headers = {"X-AUTH-TOKEN": authToken, "Accept": "text/json"}
    fullUrl = serverProto + "://" + serverAddress + "/" + customUri + '/api/latest' + endpointUrl + "/" + str(idToDelete)
    logging.debug("cv2api_deleteGeneric() deleting on endpoint '" + endpointUrl + "' id '" + str(idToDelete) + "'")
    response = requests.delete(fullUrl, headers=post_headers)
    if response.status_code != 204:
        body = json.loads(str(response.content.decode()))
    else:
        body = "empty"
    
    match str(response.status_code):
        case '204':
            logging.debug("API call succeeded.")
        case '409':
            logging.warning("API call failed, object probably already deleted. Response: " + str(body))
        case '400'|'404':
            logging.error("API call failed. Response: " + str(body))
    logging.debug("cv2api_deleteGeneric() ending")
    return(str(body))

def cv2api_deleteHostGroup(serverAddress: str, idToDelete: int, authToken, customUri: str = "centreon", serverProto: str = "http"):
    logging.debug('cv2api_deleteHostGroup() starting')
    logging.debug('cv2api_deleteHostGroup() deleting host group ' + str(idToDelete))
    body = cv2api_deleteGeneric(serverAddress, '/configuration/hosts/groups', authToken, idToDelete=idToDelete)
    logging.debug('cv2api_deleteHostGroup() ending')
    return body

def cv2api_deleteHostCategory(serverAddress: str, idToDelete: int, authToken, customUri: str = "centreon", serverProto: str = "http"):
    logging.debug('cv2api_deleteHostCategory() starting')
    body = cv2api_deleteGeneric(serverAddress, '/configuration/hosts/categories', authToken=authToken, idToDelete=idToDelete)
    logging.debug('cv2api_deleteHostCategory() ending')
    return body

def cv2api_deleteHostSeverity(serverAddress: str, idToDelete: int, authToken, customUri: str = "centreon", serverProto: str = "http"):
    logging.debug('cv2api_deleteHostCategory() starting')
    body = cv2api_deleteGeneric(serverAddress, '/configuration/hosts/severities', authToken=authToken, idToDelete=idToDelete)
    logging.debug('cv2api_deleteHostCategory() ending')
    return body

def cv2api_deleteServiceGroup(serverAddress: str, idToDelete: int, authToken, customUri: str = "centreon", serverProto: str = "http"):
    logging.debug('cv2api_deleteServiceGroup() starting')
    body = cv2api_deleteGeneric(serverAddress, '/configuration/services/groups', authToken=authToken, idToDelete=idToDelete)
    logging.debug('cv2api_deleteServiceGroup() ending')
    return body

def cv2api_deleteServiceCategory(serverAddress: str, idToDelete: int, authToken, customUri: str = "centreon", serverProto: str = "http"):
    logging.debug('cv2api_deleteServiceCategory() starting')
    body = cv2api_deleteGeneric(serverAddress, '/configuration/services/categories', authToken=authToken, idToDelete=idToDelete)
    logging.debug('cv2api_deleteServiceCategory() ending')
    return body

def cv2api_deleteServiceSeverity(serverAddress: str, idToDelete: int, authToken, customUri: str = "centreon", serverProto: str = "http"):
    logging.debug('cv2api_deleteServiceSeverity() starting')
    body = cv2api_deleteGeneric(serverAddress, '/configuration/services/severities', authToken=authToken, idToDelete=idToDelete)
    logging.debug('cv2api_deleteServiceSeverity() ending')
    return body

def main():
    logging.debug('main() starting')
    """baseUrl = 'http://192.168.59.134/centreon/api/latest'
    epAuth = '/login'
    centreonServer = '192.168.59.134'
    centreonLogin = 'admin'
    centreonPassword = 'centreon'"""

    logging.info("Reading config file")
    config_data = json.loads(load_file(str(Path(__file__).parent.resolve()) + "/config.json"))
    centreonServer = config_data['centreonServer']
    centreonCustomUri = config_data['centreonCustomUri']
    centreonProto = config_data['centreonProto']
    centreonLogin = config_data['centreonLogin']
    centreonPassword = config_data['centreonPassword']

    logging.info("Authenticating")

    myToken = cv2api_authenticate(serverAddress=centreonServer, userName=centreonLogin, userPassword=centreonPassword, customUri=centreonCustomUri, serverProto=centreonProto)
    
    # Delete all host groups
    arrayOfObjs = cv2api_getHostGroups(serverAddress=centreonServer, authToken=myToken)["result"]
    logging.info("Deleting " + str(len(arrayOfObjs)) + " host groups")
    for obj in arrayOfObjs:
        cv2api_deleteHostGroup(centreonServer, authToken=myToken, idToDelete=obj["id"])

    # Delete all host categories
    arrayOfObjs = cv2api_getHostCategories(serverAddress=centreonServer, authToken=myToken)["result"]
    logging.info("Deleting " + str(len(arrayOfObjs)) + " host categories")
    for obj in arrayOfObjs:
        cv2api_deleteHostCategory(serverAddress=centreonServer, authToken=myToken, idToDelete=obj["id"])

    # Delete all host severities
    arrayOfObjs = cv2api_getHostSeverities(serverAddress=centreonServer, authToken=myToken)["result"]
    logging.info("Deleting " + str(len(arrayOfObjs)) + " host severities")
    for obj in arrayOfObjs:
        cv2api_deleteHostSeverity(serverAddress=centreonServer, authToken=myToken, idToDelete=obj["id"])

    # Delete all service groups
    arrayOfObjs = cv2api_getServiceGroups(serverAddress=centreonServer, authToken=myToken)["result"]
    logging.info("Deleting " + str(len(arrayOfObjs)) + " service groups")
    for obj in arrayOfObjs:
        cv2api_deleteServiceGroup(centreonServer, authToken=myToken, idToDelete=obj["id"])

    # Delete all service categories
    arrayOfObjs = cv2api_getServiceCategories(serverAddress=centreonServer, authToken=myToken)["result"]
    logging.info("Deleting " + str(len(arrayOfObjs)) + " service categories")
    for obj in arrayOfObjs:
        cv2api_deleteServiceCategory(serverAddress=centreonServer, authToken=myToken, idToDelete=obj["id"])

    # Delete all service severities
    arrayOfObjs = cv2api_getServiceSeverities(serverAddress=centreonServer, authToken=myToken)["result"]
    logging.info("Deleting " + str(len(arrayOfObjs)) + " service severities")
    for obj in arrayOfObjs:
        cv2api_deleteServiceSeverity(serverAddress=centreonServer, authToken=myToken, idToDelete=obj["id"])

    logging.debug('main() ending')


logging.basicConfig(encoding='utf-8', level=logging.INFO, format='[%(asctime)s][%(levelname)s] %(message)s')
logging.info('Script starting')
main()
logging.info('Script ending')