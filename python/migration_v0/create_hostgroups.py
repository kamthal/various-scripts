import json
import pathlib
import requests

baseUrl = 'http://192.168.59.134/centreon/api/latest'
epAuth = '/login'

login = 'admin'
password = 'centreon'
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
authToken = str(body['security']['token'])


fh = open(
    str(pathlib.Path(__file__).parent.resolve()) + "/source_data/host_groups.json",
    "r"
    )
json_input = fh.read()
fh.close()
print(json_input)

data_input = json.loads(json_input)

for hg in data_input:
    print(json.dumps(hg))
    post_data=str(json.dumps(hg))
    post_headers = {"X-AUTH-TOKEN": authToken, "Accept": "*/*"}
    response = requests.post(baseUrl + '/configuration/hosts/groups', headers=post_headers, json=hg)
    body = json.loads(str(response.content.decode()))
    print(str(body))

