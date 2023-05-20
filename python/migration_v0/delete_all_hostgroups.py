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
post_headers = {"X-AUTH-TOKEN": authToken, "Accept": "*/*"}
response = requests.get(baseUrl + '/configuration/hosts/groups', headers=post_headers)
#body = json.loads(str(response.content.decode()))
dec = response.content.decode()
body = json.loads(dec)
hGroups = body["result"]
for hg in hGroups:
    id = hg["id"]
    print("%s" % id )
    requests.delete(baseUrl + '/configuration/hosts/groups/' + str(id) , headers=post_headers)
response = requests.get(baseUrl + '/configuration/hosts/categories', headers=post_headers)
#body = json.loads(str(response.content.decode()))
dec = response.content.decode()
body = json.loads(dec)
hCategories = body["result"]
for hc in hCategories:
    id = hc["id"]
    print("%s" % id )
    requests.delete(baseUrl + '/configuration/hosts/categories/' + str(id) , headers=post_headers)
