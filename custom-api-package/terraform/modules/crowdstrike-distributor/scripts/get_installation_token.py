import http.client
import json


def script_handler(events, context):
    try:
        print('Requesting Installtion Token from Crowdstrike backend.')
        conn = http.client.HTTPSConnection(events["FalconCloud"])

        headers = {
            'Authorization': "Bearer {}".format(events["AuthToken"])
        }

        conn.request("GET", "/installation-tokens/queries/tokens/v1?filter=status:'valid'", "", headers)
        res = conn.getresponse()

        if res.status != 200:
            raise ValueError(
                'Received non success response {} while querying for token. Error {}'.format(res.status, res.reason))

        queryResData = res.read()
        resId = json.loads(queryResData)['resources'][0]

        url = "/installation-tokens/entities/tokens/v1?ids={}".format(resId)
        conn.request("GET", url, "", headers)
        entitiesRes = conn.getresponse()

        if entitiesRes.status != 200:
            raise ValueError(
                'Received non success response {} while fetching token by id. Error {}'.format(res.status, res.reason))

        entitiesResData = entitiesRes.read()
        token = json.loads(entitiesResData)['resources'][0]['value']

        print('Successfully received Installation token')
        return {'InstallationToken': token}
    except Exception as e:
        raise ValueError('Failure while interacting with Crowdstrike backend. Error {}'.format(e))