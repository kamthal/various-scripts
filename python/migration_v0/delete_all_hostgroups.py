import json
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
# Delete all host groups
response = requests.get(baseUrl + '/configuration/hosts/groups', headers=post_headers)
#body = json.loads(str(response.content.decode()))
dec = response.content.decode()
body = json.loads(dec)
hGroups = body["result"]
for hg in hGroups:
    id = hg["id"]
    print("%s" % id )
    requests.delete(baseUrl + '/configuration/hosts/groups/' + str(id) , headers=post_headers)
# Delete all host categories
response = requests.get(baseUrl + '/configuration/hosts/categories', headers=post_headers)
dec = response.content.decode()
body = json.loads(dec)
hCategories = body["result"]
for hc in hCategories:
    id = hc["id"]
    print("%s" % id )
    requests.delete(baseUrl + '/configuration/hosts/categories/' + str(id) , headers=post_headers)
# Delete all host severities
response = requests.get(baseUrl + '/configuration/hosts/severities', headers=post_headers)
dec = response.content.decode()
body = json.loads(dec)
hSeverities = body["result"]
for hs in hSeverities:
    id = hs["id"]
    print("%s" % id )
    requests.delete(baseUrl + '/configuration/hosts/severities/' + str(id) , headers=post_headers)
# Delete all service groups
response = requests.get(baseUrl + '/configuration/services/groups', headers=post_headers)
#body = json.loads(str(response.content.decode()))
dec = response.content.decode()
body = json.loads(dec)
sGroups = body["result"]
for sg in sGroups:
    id = sg["id"]
    print("%s" % id )
    requests.delete(baseUrl + '/configuration/services/groups/' + str(id) , headers=post_headers)
# Delete all service categories
response = requests.get(baseUrl + '/configuration/services/categories', headers=post_headers)
dec = response.content.decode()
body = json.loads(dec)
sCategories = body["result"]
for sc in sCategories:
    id = sc["id"]
    print("%s" % id )
    requests.delete(baseUrl + '/configuration/services/categories/' + str(id) , headers=post_headers)
# Delete all service severities
response = requests.get(baseUrl + '/configuration/services/severities', headers=post_headers)
dec = response.content.decode()
body = json.loads(dec)
sSeverities = body["result"]
for ss in sSeverities:
    id = ss["id"]
    print("%s" % id )
    requests.delete(baseUrl + '/configuration/services/severities/' + str(id) , headers=post_headers)
