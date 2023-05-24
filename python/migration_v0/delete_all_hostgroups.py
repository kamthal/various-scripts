import json
import requests
import logging
from pathlib import Path
import centreon_api

def main():
    logging.debug('main() starting')
    """baseUrl = 'http://192.168.59.134/centreon/api/latest'
    epAuth = '/login'
    centreonServer = '192.168.59.134'
    centreonLogin = 'admin'
    centreonPassword = 'centreon'"""

    logging.info("Reading config file")
    config_data = json.loads(centreon_api.load_file(str(Path(__file__).parent.resolve()) + "/config.json"))
    centreonServer = config_data['centreonServer']
    centreonCustomUri = config_data['centreonCustomUri']
    centreonProto = config_data['centreonProto']
    centreonLogin = config_data['centreonLogin']
    centreonPassword = config_data['centreonPassword']

    logging.info("Authenticating")

    myToken = centreon_api.authenticate(serverAddress=centreonServer, userName=centreonLogin, userPassword=centreonPassword, customUri=centreonCustomUri, serverProto=centreonProto)
    
    # Delete all host groups
    arrayOfObjs = centreon_api.getHostGroups(serverAddress=centreonServer, authToken=myToken)["result"]
    logging.info("Deleting " + str(len(arrayOfObjs)) + " host groups")
    for obj in arrayOfObjs:
        centreon_api.deleteHostGroup(centreonServer, authToken=myToken, idToDelete=obj["id"])

    # Delete all host categories
    arrayOfObjs = centreon_api.getHostCategories(serverAddress=centreonServer, authToken=myToken)["result"]
    logging.info("Deleting " + str(len(arrayOfObjs)) + " host categories")
    for obj in arrayOfObjs:
        centreon_api.deleteHostCategory(serverAddress=centreonServer, authToken=myToken, idToDelete=obj["id"])

    # Delete all host severities
    arrayOfObjs = centreon_api.getHostSeverities(serverAddress=centreonServer, authToken=myToken)["result"]
    logging.info("Deleting " + str(len(arrayOfObjs)) + " host severities")
    for obj in arrayOfObjs:
        centreon_api.deleteHostSeverity(serverAddress=centreonServer, authToken=myToken, idToDelete=obj["id"])

    # Delete all service groups
    arrayOfObjs = centreon_api.getServiceGroups(serverAddress=centreonServer, authToken=myToken)["result"]
    logging.info("Deleting " + str(len(arrayOfObjs)) + " service groups")
    for obj in arrayOfObjs:
        centreon_api.deleteServiceGroup(centreonServer, authToken=myToken, idToDelete=obj["id"])

    # Delete all service categories
    arrayOfObjs = centreon_api.getServiceCategories(serverAddress=centreonServer, authToken=myToken)["result"]
    logging.info("Deleting " + str(len(arrayOfObjs)) + " service categories")
    for obj in arrayOfObjs:
        centreon_api.deleteServiceCategory(serverAddress=centreonServer, authToken=myToken, idToDelete=obj["id"])

    # Delete all service severities
    arrayOfObjs = centreon_api.getServiceSeverities(serverAddress=centreonServer, authToken=myToken)["result"]
    logging.info("Deleting " + str(len(arrayOfObjs)) + " service severities")
    for obj in arrayOfObjs:
        centreon_api.deleteServiceSeverity(serverAddress=centreonServer, authToken=myToken, idToDelete=obj["id"])

    logging.debug('main() ending')


logging.basicConfig(encoding='utf-8', level=logging.INFO, format='[%(asctime)s][%(levelname)s] %(message)s')
logging.info('Script starting')
main()
logging.info('Script ending')