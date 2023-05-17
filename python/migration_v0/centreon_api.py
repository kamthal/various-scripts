import json
import requests

def cv2api_authenticate(serverAddress: str, userName: str = "admin", userPassword: str = "centreon", customUri: str = "centreon", serverProto: str = "http") -> str:
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
    return(str(body['security']['token']))

print(cv2api_authenticate('192.168.59.134'))

