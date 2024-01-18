import http.client
import mimetypes
import urllib.parse
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
      raise ValueError('Received non success response {}. Error {}'.format(res.status, res.reason))

    data = res.read()
    print('Successfully received Customer ID.')
    return {'CCID': json.loads(data)['resources'][0]}
  except Exception as e:
    raise ValueError('Failure while interacting with Crowdstrike backend. Error {}'.format(e))