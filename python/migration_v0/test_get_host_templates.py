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
    arrayOfObjs = centreonV2Api.getHostTemplates(serverAddress=centreonServer, authToken=myToken)["result"]
    logging.info("Deleting " + str(len(arrayOfObjs)) + " host groups")
    for obj in arrayOfObjs:
        centreonV2Api.deleteHostTemplate(centreonServer, authToken=myToken, idToDelete=obj["id"])

    """fh = open(str(Path(__file__).parent.resolve()) + "/templates.json", "w")
    fh.write(str(json.dumps(arrayOfObjs)))
    fh.close()"""

    logging.debug('main() ending')


logging.basicConfig(encoding='utf-8', level=logging.DEBUG, format='[%(asctime)s][%(levelname)s] %(message)s')
logging.info('Script starting')
main()
logging.info('Script ending')