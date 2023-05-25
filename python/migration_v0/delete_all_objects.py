import json
import requests
import logging
from pathlib import Path
import centreonV2Api

def main():
    logging.debug('main() starting')
    """baseUrl = 'http://192.168.59.134/centreon/api/latest'
    epAuth = '/login'
    centreonServer = '192.168.59.134'
    centreonLogin = 'admin'
    centreonPassword = 'centreon'"""

    logging.info("Reading config file")
    config_data = json.loads(centreonV2Api.load_file(str(Path(__file__).parent.resolve()) + "/config.json"))
    centreonServer = config_data['centreonServer']
    centreonCustomUri = config_data['centreonCustomUri']
    centreonProto = config_data['centreonProto']
    centreonLogin = config_data['centreonLogin']
    centreonPassword = config_data['centreonPassword']

    logging.info("Authenticating")

    myToken = centreonV2Api.authenticate(serverAddress=centreonServer, userName=centreonLogin, userPassword=centreonPassword, customUri=centreonCustomUri, serverProto=centreonProto)
    
    # Delete all host groups
    while (len(arrayOfObjs := centreonV2Api.getHostGroups(serverAddress=centreonServer, authToken=myToken)["result"]) > 0):
        logging.info("Deleting " + str(len(arrayOfObjs)) + " host groups")
        for obj in arrayOfObjs:
            centreonV2Api.deleteHostGroup(centreonServer, authToken=myToken, idToDelete=obj["id"])

    # Delete all host categories
    while (len(arrayOfObjs := centreonV2Api.getHostCategories(serverAddress=centreonServer, authToken=myToken)["result"])):
        logging.info("Deleting " + str(len(arrayOfObjs)) + " host categories")
        for obj in arrayOfObjs:
            centreonV2Api.deleteHostCategory(serverAddress=centreonServer, authToken=myToken, idToDelete=obj["id"])

    # Delete all host severities
    while (len(arrayOfObjs := centreonV2Api.getHostSeverities(serverAddress=centreonServer, authToken=myToken)["result"])):
        logging.info("Deleting " + str(len(arrayOfObjs)) + " host severities")
        for obj in arrayOfObjs:
            centreonV2Api.deleteHostSeverity(serverAddress=centreonServer, authToken=myToken, idToDelete=obj["id"])

    # Delete all host templates
    while (len(arrayOfObjs := centreonV2Api.getHostTemplates(serverAddress=centreonServer, authToken=myToken)["result"])):
        logging.info("Deleting " + str(len(arrayOfObjs)) + " host templates")
        for obj in arrayOfObjs:
            centreonV2Api.deleteHostTemplate(serverAddress=centreonServer, authToken=myToken, idToDelete=obj["id"])

    # Delete all service groups
    while (len(arrayOfObjs := centreonV2Api.getServiceGroups(serverAddress=centreonServer, authToken=myToken)["result"])):
        logging.info("Deleting " + str(len(arrayOfObjs)) + " service groups")
        for obj in arrayOfObjs:
            centreonV2Api.deleteServiceGroup(centreonServer, authToken=myToken, idToDelete=obj["id"])

    # Delete all service categories
    while (len(arrayOfObjs := centreonV2Api.getServiceCategories(serverAddress=centreonServer, authToken=myToken)["result"])):
        logging.info("Deleting " + str(len(arrayOfObjs)) + " service categories")
        for obj in arrayOfObjs:
            centreonV2Api.deleteServiceCategory(serverAddress=centreonServer, authToken=myToken, idToDelete=obj["id"])

    # Delete all service severities
    while (len(arrayOfObjs := centreonV2Api.getServiceSeverities(serverAddress=centreonServer, authToken=myToken)["result"])):
        logging.info("Deleting " + str(len(arrayOfObjs)) + " service severities")
        for obj in arrayOfObjs:
            centreonV2Api.deleteServiceSeverity(serverAddress=centreonServer, authToken=myToken, idToDelete=obj["id"])

    # Delete all service templates
    while (len(arrayOfObjs := centreonV2Api.getServiceTemplates(serverAddress=centreonServer, authToken=myToken)["result"])):
        logging.info("Deleting " + str(len(arrayOfObjs)) + " service templates")
        for obj in arrayOfObjs:
            centreonV2Api.deleteServiceTemplate(serverAddress=centreonServer, authToken=myToken, idToDelete=obj["id"])

    logging.debug('main() ending')


logging.basicConfig(encoding='utf-8', level=logging.INFO, format='[%(asctime)s][%(levelname)s] %(message)s')
logging.info('Script starting')
main()
logging.info('Script ending')