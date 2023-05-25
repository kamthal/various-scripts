import logging
import json
from pathlib import Path
import centreonV2Api


def main():
    logging.debug('main() starting')

    logging.info("Reading config file")
    config_data = json.loads(centreonV2Api.load_file(str(Path(__file__).parent.resolve()) + "/config.json"))
    centreonServer = config_data['centreonServer']
    centreonCustomUri = config_data['centreonCustomUri']
    centreonProto = config_data['centreonProto']
    centreonLogin = config_data['centreonLogin']
    centreonPassword = config_data['centreonPassword']

    logging.info("Authenticating")
    myToken = centreonV2Api.authenticate(serverAddress=centreonServer, userName=centreonLogin, userPassword=centreonPassword, customUri=centreonCustomUri, serverProto=centreonProto)

    arrayOfObjs = json.loads(centreonV2Api.load_file(str(Path(__file__).parent.resolve()) + "/source_data/host_groups.json"))
    logging.info("Creating " + str(len(arrayOfObjs)) + " host groups")
    for obj in arrayOfObjs:
        centreonV2Api.createHostGroup(centreonServer, obj, myToken)
    
    arrayOfObjs = json.loads(centreonV2Api.load_file(str(Path(__file__).parent.resolve()) + "/source_data/host_categories.json"))
    logging.info("Creating " + str(len(arrayOfObjs)) + " host categories")
    for obj in arrayOfObjs:
        centreonV2Api.createHostCategory(centreonServer, obj, myToken)
    
    arrayOfObjs = json.loads(centreonV2Api.load_file(str(Path(__file__).parent.resolve()) + "/source_data/host_severities.json"))
    logging.info("Creating " + str(len(arrayOfObjs)) + " host severities")
    for obj in arrayOfObjs:
        centreonV2Api.createHostSeverity(centreonServer, obj, myToken)

    arrayOfObjs = json.loads(centreonV2Api.load_file(str(Path(__file__).parent.resolve()) + "/source_data/host_templates.json"))
    logging.info("Creating " + str(len(arrayOfObjs)) + " host templates")
    for obj in arrayOfObjs:
        centreonV2Api.createHostTemplate(centreonServer, obj, myToken)

    arrayOfObjs = json.loads(centreonV2Api.load_file(str(Path(__file__).parent.resolve()) + "/source_data/service_groups.json"))
    logging.info("Creating " + str(len(arrayOfObjs)) + " service groups")
    for obj in arrayOfObjs:
        centreonV2Api.createServiceGroup(centreonServer, obj, myToken)
    
    arrayOfObjs = json.loads(centreonV2Api.load_file(str(Path(__file__).parent.resolve()) + "/source_data/service_categories.json"))
    logging.info("Creating " + str(len(arrayOfObjs)) + " service categories")
    for obj in arrayOfObjs:
        centreonV2Api.createServiceCategory(centreonServer, obj, myToken)
    
    arrayOfObjs = json.loads(centreonV2Api.load_file(str(Path(__file__).parent.resolve()) + "/source_data/service_severities.json"))
    logging.info("Creating " + str(len(arrayOfObjs)) + " service severities")
    for obj in arrayOfObjs:
        centreonV2Api.createServiceSeverity(centreonServer, obj, myToken)

    logging.debug('main() ending')

logging.basicConfig(encoding='utf-8', level=logging.INFO, format='[%(asctime)s][%(levelname)s] %(message)s')
logging.info('Script starting')
main()
logging.info('Script ending')
