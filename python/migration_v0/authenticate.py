import json
import requests

baseUrl = 'http://192.168.59.134/centreon'
login = 'admin'
password = 'centreon'

epAuth = '/api/latest/login'

json_credentials = {
    "security": {
        "credentials": {
            "login": login,
            "password": password
        }
    }
}

response = requests.post(baseUrl+epAuth, json=json_credentials)
body = json.loads(str(response.content.decode()))
print(str(body['security']['token']))

