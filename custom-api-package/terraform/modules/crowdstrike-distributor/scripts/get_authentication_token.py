import http.client
import mimetypes
import urllib.parse
import boto3
import json

def script_handler(events, context):
  print('Configuring AWS region {}'.format(events['Region']))
  ssm = boto3.client('ssm', region_name=events['Region'])

  print('Fetching required configuration from Parameter Service')

  print('... Fetching FalconCloud')
  apiGateWayHostResponse = ssm.get_parameter(Name=events['FalconCloud'], WithDecryption=True)
  if apiGateWayHostResponse['ResponseMetadata']['HTTPStatusCode'] != 200:
    raise ValueError('Required property {} not found'.format(events['FalconCloud']))

  print('... Fetching FalconClientId')
  apiGatewayClientIDResponse = ssm.get_parameter(Name=events['FalconClientId'], WithDecryption=True)
  if apiGatewayClientIDResponse['ResponseMetadata']['HTTPStatusCode'] != 200:
    raise ValueError('Required property {} not found'.format(events['FalconClientId']))

  print('... Fetching FalconClientSecret')
  apiGatewayClientSecretResponse = ssm.get_parameter(Name=events['FalconClientSecret'], WithDecryption=True)
  if apiGatewayClientSecretResponse['ResponseMetadata']['HTTPStatusCode'] != 200:
    raise ValueError('Required property {} not found'.format(events['FalconClientSecret']))

  apiGateWayHostValue = apiGateWayHostResponse['Parameter']['Value']
  apiGateWayHostValue = apiGateWayHostValue.replace("https://", "").replace("http://", "")
  apiGatewayClientIDValue = apiGatewayClientIDResponse['Parameter']['Value']
  apiGatewayClientSecretValue = apiGatewayClientSecretResponse['Parameter']['Value']

  try:
    print('Requesting Authentication token from Crowdstrike backend.')
    conn = http.client.HTTPSConnection(apiGateWayHostValue)
    params = urllib.parse.urlencode({'client_id': apiGatewayClientIDValue, 'client_secret': apiGatewayClientSecretValue})
    headers = {'Content-Type': 'application/x-www-form-urlencoded'}
    conn.request('POST', '/oauth2/token', params, headers)
    res = conn.getresponse()

    if res.status != 201:
      raise ValueError('Received non success response {}. Error {}'.format(res.status, res.reason))

    data = res.read()
    print('Successfully received OAuth token.')
    return {'AuthToken': json.loads(data)['access_token'], 'ApiGatewayHost':apiGateWayHostValue}
  except Exception as e:
    raise ValueError('Failure while interacting with Crowdstrike backend. Error: {}'.format(e))