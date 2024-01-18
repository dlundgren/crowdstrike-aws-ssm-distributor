import http.client
import urllib.parse
import boto3
import json


def load_secret(events):
    sm = boto3.client('secretsmanager', region_name=events['Region'])
    response = sm.get_secret_value(SecretId=events['SecretName'])
    secret = json.loads(response['SecretString'])
    return (secret['Cloud'], secret['ClientId'], secret['ClientSecret'])


def load_params(events):
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

    return (
        apiGateWayHostValue.replace("https://", "").replace("http://", ""),
        apiGatewayClientIDResponse['Parameter']['Value'],
        apiGatewayClientSecretResponse['Parameter']['Value']
    )


def script_handler(events, context):
    if 'SecretName' in events and len(events['SecretName']) > 0:
        (cloudHost, clientId, clientSecret) = load_secret(events)
    else:
        (cloudHost, clientId, clientSecret) = load_params(events)
    try:
        print('Requesting Authentication token from Crowdstrike backend.')
        conn = http.client.HTTPSConnection(cloudHost)
        params = urllib.parse.urlencode({'client_id': clientId, 'client_secret': clientSecret})
        headers = {'Content-Type': 'application/x-www-form-urlencoded'}
        conn.request('POST', '/oauth2/token', params, headers)
        res = conn.getresponse()
        if res.status != 201:
            raise ValueError('Received non success response {}. Error {}'.format(res.status, res.reason))

        print('Successfully received OAuth token.')
        return {'AuthToken': json.loads(res.read())['access_token'], 'ApiGatewayHost': cloudHost}
    except Exception as e:
        raise ValueError('Failure while interacting with Crowdstrike backend. Error: {}'.format(e))
