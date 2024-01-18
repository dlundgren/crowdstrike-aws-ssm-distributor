import http.client
import json


def script_handler(events, context):
    try:
        print('Requesting Customer ID from Crowdstrike backend.')
        conn = http.client.HTTPSConnection(events["FalconCloud"])
        headers = {
            'Authorization': "Bearer {}".format(events["AuthToken"])
        }

        conn.request("GET", "/sensors/queries/installers/ccid/v1", "", headers)
        res = conn.getresponse()

        if res.status != 200:
            raise ValueError(f'Received non success response {res.status}. Error {res.reason}')

        print('Successfully received Customer ID.')
        return {'CCID': json.loads(res.read())['resources'][0]}
    except Exception as e:
        raise ValueError('Failure while interacting with Crowdstrike backend. Error {}'.format(e))
