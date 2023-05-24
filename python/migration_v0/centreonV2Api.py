import json
import requests
import logging
import sys

def load_file(filePath):
    logging.debug('load_file() starting')

    fh = open(filePath, "r")
    file_content = fh.read()
    fh.close()

    logging.debug('load_file() ending')
    return(file_content)

def authenticate(serverAddress: str, userName: str = "admin", userPassword: str = "centreon", customUri: str = "centreon", serverProto: str = "http") -> str:
    logging.debug("authenticate() starting")

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
    logging.debug("authenticate() ending")
    return(str(body['security']['token']))

def load_file(filePath):
    fh = open(
        filePath,
        "r"
        )
    file_content = fh.read()
    fh.close()
    return(file_content)

def getGeneric(serverAddress: str, endpointUrl, authToken, customUri: str = "centreon", serverProto: str = "http"):
    logging.debug("getGeneric() starting")
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
    logging.debug("getGeneric() ending")
    return(body)

def getHostGroups(serverAddress: str, authToken: str, customUri: str = "centreon", serverProto: str = "http"):
    logging.debug('getHostGroups() starting')
    body = getGeneric(serverAddress, '/configuration/hosts/groups', authToken=authToken)
    logging.debug('getHostGroups() starting')
    return(body)

def getHostCategories(serverAddress: str, authToken: str, customUri: str = "centreon", serverProto: str = "http"):
    logging.debug('getHostCategories() starting')
    body = getGeneric(serverAddress, '/configuration/hosts/categories', authToken=authToken)
    logging.debug('getHostCategories() starting')
    return(body)

def getHostSeverities(serverAddress: str, authToken: str, customUri: str = "centreon", serverProto: str = "http"):
    logging.debug('getHostSeverities() starting')
    body = getGeneric(serverAddress, '/configuration/hosts/severities', authToken=authToken)
    logging.debug('getHostSeverities() starting')
    return(body)

def getHostTemplates(serverAddress: str, authToken: str, customUri: str = "centreon", serverProto: str = "http"):
    logging.debug('getHostTemplates() starting')
    body = getGeneric(serverAddress, '/configuration/hosts/templates', authToken=authToken)
    logging.debug('getHostTemplates() starting')
    return(body)

def getServiceGroups(serverAddress: str, authToken: str, customUri: str = "centreon", serverProto: str = "http"):
    logging.debug('getServiceGroup() starting')
    body = getGeneric(serverAddress, '/configuration/services/groups', authToken=authToken)
    logging.debug('getServiceGroup() starting')
    return(body)

def getServiceCategories(serverAddress: str, authToken: str, customUri: str = "centreon", serverProto: str = "http"):
    logging.debug('getServiceCategorie() starting')
    body = getGeneric(serverAddress, '/configuration/services/categories', authToken=authToken)
    logging.debug('getServiceCategorie() starting')
    return(body)

def getServiceSeverities(serverAddress: str, authToken: str, customUri: str = "centreon", serverProto: str = "http"):
    logging.debug('getServiceSeveritie() starting')
    body = getGeneric(serverAddress, '/configuration/services/severities', authToken=authToken)
    logging.debug('getServiceSeveritie() starting')
    return(body)

def createGeneric(serverAddress: str, endpointUrl, authToken, jsonData, customUri: str = "centreon", serverProto: str = "http"):
    logging.debug("createGeneric() starting")
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
    logging.debug("createGeneric() ending")
    return(str(body))

def createHostGroup(serverAddress: str, jsonData, authToken, customUri: str = "centreon", serverProto: str = "http"):
    return createGeneric(serverAddress, '/configuration/hosts/groups', authToken, jsonData)

def createHostCategory(serverAddress: str, jsonData, authToken, customUri: str = "centreon", serverProto: str = "http"):
    return createGeneric(serverAddress, '/configuration/hosts/categories', authToken, jsonData)

def createHostSeverity(serverAddress: str, jsonData, authToken, customUri: str = "centreon", serverProto: str = "http"):
    return createGeneric(serverAddress, '/configuration/hosts/severities', authToken, jsonData)

def createServiceGroup(serverAddress: str, jsonData, authToken, customUri: str = "centreon", serverProto: str = "http"):
    return createGeneric(serverAddress, '/configuration/services/groups', authToken, jsonData)

def createServiceCategory(serverAddress: str, jsonData, authToken, customUri: str = "centreon", serverProto: str = "http"):
    return createGeneric(serverAddress, '/configuration/services/categories', authToken, jsonData)

def createServiceSeverity(serverAddress: str, jsonData, authToken, customUri: str = "centreon", serverProto: str = "http"):
    return createGeneric(serverAddress, '/configuration/services/severities', authToken, jsonData)

def deleteGeneric(serverAddress: str, endpointUrl, authToken, idToDelete:int, customUri: str = "centreon", serverProto: str = "http"):
    logging.debug("deleteGeneric() starting")
    post_headers = {"X-AUTH-TOKEN": authToken, "Accept": "text/json"}
    fullUrl = serverProto + "://" + serverAddress + "/" + customUri + '/api/latest' + endpointUrl + "/" + str(idToDelete)
    logging.debug("deleteGeneric() deleting on endpoint '" + endpointUrl + "' id '" + str(idToDelete) + "'")
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
    logging.debug("deleteGeneric() ending")
    return(str(body))

def deleteHostGroup(serverAddress: str, idToDelete: int, authToken, customUri: str = "centreon", serverProto: str = "http"):
    logging.debug('deleteHostGroup() starting')
    logging.debug('deleteHostGroup() deleting host group ' + str(idToDelete))
    body = deleteGeneric(serverAddress, '/configuration/hosts/groups', authToken, idToDelete=idToDelete)
    logging.debug('deleteHostGroup() ending')
    return body

def deleteHostCategory(serverAddress: str, idToDelete: int, authToken, customUri: str = "centreon", serverProto: str = "http"):
    logging.debug('deleteHostCategory() starting')
    body = deleteGeneric(serverAddress, '/configuration/hosts/categories', authToken=authToken, idToDelete=idToDelete)
    logging.debug('deleteHostCategory() ending')
    return body

def deleteHostSeverity(serverAddress: str, idToDelete: int, authToken, customUri: str = "centreon", serverProto: str = "http"):
    logging.debug('deleteHostCategory() starting')
    body = deleteGeneric(serverAddress, '/configuration/hosts/severities', authToken=authToken, idToDelete=idToDelete)
    logging.debug('deleteHostCategory() ending')
    return body

def deleteServiceGroup(serverAddress: str, idToDelete: int, authToken, customUri: str = "centreon", serverProto: str = "http"):
    logging.debug('deleteServiceGroup() starting')
    body = deleteGeneric(serverAddress, '/configuration/services/groups', authToken=authToken, idToDelete=idToDelete)
    logging.debug('deleteServiceGroup() ending')
    return body

def deleteServiceCategory(serverAddress: str, idToDelete: int, authToken, customUri: str = "centreon", serverProto: str = "http"):
    logging.debug('deleteServiceCategory() starting')
    body = deleteGeneric(serverAddress, '/configuration/services/categories', authToken=authToken, idToDelete=idToDelete)
    logging.debug('deleteServiceCategory() ending')
    return body

def deleteServiceSeverity(serverAddress: str, idToDelete: int, authToken, customUri: str = "centreon", serverProto: str = "http"):
    logging.debug('deleteServiceSeverity() starting')
    body = deleteGeneric(serverAddress, '/configuration/services/severities', authToken=authToken, idToDelete=idToDelete)
    logging.debug('deleteServiceSeverity() ending')
    return body

def deleteHostTemplate(serverAddress: str, idToDelete: int, authToken, customUri: str = "centreon", serverProto: str = "http"):
    logging.debug('deleteHostTemplate() starting - deleting host template ' + str(idToDelete))
    body = deleteGeneric(serverAddress, '/configuration/hosts/templates', authToken, idToDelete=idToDelete)
    logging.debug('deleteHostTemplate() ending')
    return body
