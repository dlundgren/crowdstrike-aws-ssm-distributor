import http.client
import json


def script_handler(events, context):
    try:
        print('Requesting Installation Token from Crowdstrike backend.')
        conn = http.client.HTTPSConnection(events["FalconCloud"])

        headers = {
            'Authorization': "Bearer {}".format(events["AuthToken"])
        }

        # retrieve a valid token id
        conn.request("GET", "/installation-tokens/queries/tokens/v1?filter=status:'valid'", "", headers)
        res = conn.getresponse()
        if res.status != 200:
            raise ValueError(
                f'Received non success response {res.status} while querying for token. Error {res.reason}'
            )

        tokenId = json.loads(res.read())['resources'][0]

        # retrieve the token itself
        conn.request("GET", f"/installation-tokens/entities/tokens/v1?ids={tokenId}", "", headers)
        res = conn.getresponse()
        if res.status != 200:
            raise ValueError(
                f'Received non success response {res.status} while fetching token by id. Error {res.reason}'
            )

        token = json.loads(res.read())['resources'][0]['value']

        print('Successfully received Installation token')
        return {'InstallationToken': token}
    except Exception as e:
        raise ValueError('Failure while interacting with Crowdstrike backend. Error {}'.format(e))
