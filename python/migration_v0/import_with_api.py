import logging
import json
from pathlib import Path
import centreon_api


def main():
    logging.debug('main() starting')

    logging.info("Reading config file")
    config_data = json.loads(centreon_api.load_file(str(Path(__file__).parent.resolve()) + "/config.json"))
    centreonServer = config_data['centreonServer']
    centreonCustomUri = config_data['centreonCustomUri']
    centreonProto = config_data['centreonProto']
    centreonLogin = config_data['centreonLogin']
    centreonPassword = config_data['centreonPassword']

    logging.info("Authenticating")
    myToken = centreon_api.authenticate(serverAddress=centreonServer, userName=centreonLogin, userPassword=centreonPassword, customUri=centreonCustomUri, serverProto=centreonProto)

    arrayOfObjs = json.loads(centreon_api.load_file(str(Path(__file__).parent.resolve()) + "/source_data/host_groups.json"))
    logging.info("Creating " + str(len(arrayOfObjs)) + " host groups")
    for obj in arrayOfObjs:
        #logging.debug(json.dumps(hg))
        centreon_api.createHostGroup(centreonServer, obj, myToken)
    
    arrayOfObjs = json.loads(centreon_api.load_file(str(Path(__file__).parent.resolve()) + "/source_data/host_categories.json"))
    logging.info("Creating " + str(len(arrayOfObjs)) + " host categories")
    for obj in arrayOfObjs:
        centreon_api.createHostCategory(centreonServer, obj, myToken)
    
    arrayOfObjs = json.loads(centreon_api.load_file(str(Path(__file__).parent.resolve()) + "/source_data/host_severities.json"))
    logging.info("Creating " + str(len(arrayOfObjs)) + " host severities")
    for obj in arrayOfObjs:
        centreon_api.createHostSeverity(centreonServer, obj, myToken)

    arrayOfObjs = json.loads(centreon_api.load_file(str(Path(__file__).parent.resolve()) + "/source_data/service_groups.json"))
    logging.info("Creating " + str(len(arrayOfObjs)) + " service groups")
    for obj in arrayOfObjs:
        #logging.debug(json.dumps(hg))
        centreon_api.createServiceGroup(centreonServer, obj, myToken)
    
    arrayOfObjs = json.loads(centreon_api.load_file(str(Path(__file__).parent.resolve()) + "/source_data/service_categories.json"))
    logging.info("Creating " + str(len(arrayOfObjs)) + " service categories")
    for obj in arrayOfObjs:
        centreon_api.createServiceCategory(centreonServer, obj, myToken)
    
    arrayOfObjs = json.loads(centreon_api.load_file(str(Path(__file__).parent.resolve()) + "/source_data/service_severities.json"))
    logging.info("Creating " + str(len(arrayOfObjs)) + " service severities")
    for obj in arrayOfObjs:
        centreon_api.createServiceSeverity(centreonServer, obj, myToken)

    logging.debug('main() ending')

logging.basicConfig(encoding='utf-8', level=logging.INFO, format='[%(asctime)s][%(levelname)s] %(message)s')
logging.info('Script starting')
main()
logging.info('Script ending')
