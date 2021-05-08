import json
import logging
import boto3
from github import Github
import os
import re
import ast
import collections.abc
import inspect
import operator

log = logging.getLogger(__name__)
ssm = boto3.client('ssm')
cb = boto3.client('codebuild')
def lambda_handler(event, context):
    payload = json.loads(event['requestPayload']['body'])
    event = event['requestPayload']['headers']['X-GitHub-Event']

    with open('/opt/repo_filters.json') as f:
      #get filter groups associated with target repository
      filters = json.load(f)[payload['repository']['name']]

    print('Validating event')
    validate_event(event, filters['events'])

    print('Validating payload')
    validate_payload(payload, event, filters['filter_groups'])
    # try:
    #     valid = validate_payload(
    #         payload,
    #         event['requestPayload']['headers']['X-GitHub-Event']
    #     )
    # except Exception as e:
    #     raise LambdaException(json.dumps(
    #         {
    #             'type': e.__class__.__name__,
    #             'message': str(e)
    #         }
    #     ))

    print('Starting CodeBuild project: ', os.environ['CODEBUILD_NAME'])
    try:
        response = cb.start_build(
            projectName = os.environ['CODEBUILD_NAME'],
            sourceLocationOverride = payload['repository']['html_url'],
            sourceTypeOverride = 'GITHUB'
        )
    except Exception as e:
        raise LambdaException(json.dumps(
            {
                'type': e.__class__.__name__,
                'message': str(e)
            }
        ))

    return {'message': 'Request was successful'}

def validate_event(event, valid_events):
    #Must validate the payload event in case the user accidentally adds additional events via the Github UI
    if event not in valid_events:
        raise ClientException(
            {
                'message': f'${event} is not a valid event according to the Terraform module that created the webhook'
            }
        )

def validate_payload(payload, event, filter_groups):
    github_token = ssm.get_parameter(Name=os.environ['GITHUB_TOKEN_SSM_KEY'], WithDecryption=True)['Parameter']['Value']
    gh = Github(github_token)
    repo = gh.get_repo(payload['repository']['full_name'])
      
    if event == 'pull_request':
        valid = validate_pr(payload, filter_groups, repo)
    elif event == 'push':
        valid = validate_push(payload, filter_groups, repo)
    else:
        raise ClientException(
            {
                'message': f'Handling for event: {event} has not been created'
            }
        )

    if valid:
        print('Payload fulfills atleast one filter group')
    else:
        print('Payload does not fulfill any of the filter groups requirements')
        raise ClientException(
            {
                'message': 'Payload does not fulfill trigger requirements. Skipping Codebuild testing.'
            }
        )

def validate_filter_groups(filter_groups):
    # TODO: create if https://github.com/hashicorp/terraform/pull/25088 is not merged in near future
    # PR will allow terraform level assertions for filter_groups
    pass
    
def validate_push(payload, filter_groups, repo):
    #gets filenames of files that changed from base commit
    diff_paths = [path.filename for path in repo.compare(payload['before'], payload['after']).files]
    
    valid = False
    for group in filter_groups:
        for f in group:
            if f['exclude_matched_filter']:
                valid = operator.not_(validate_push_filter(f, payload, diff_paths))
            # if filter is invalid, continue to next filter group
            if valid == False:
                break
        # if all filters returned true from `validate_push_filter()`, skip other filter groups and return true
        if valid == True:
            break
    return valid

def validate_push_filter(filter_entry, payload, diff_paths):
    for pattern in filter_entry['file_paths']:
        for filename in diff_paths:
            if re.search(pattern, filename):
                break
            else:
                return False
    for pattern in filter_entry['commit_messages']:
        if re.search(pattern, payload['hook']['last_response']['message']):
            break
        else:
            return False
    for pattern in filter_entry['base_refs']:
        if re.search(filter_entry['pattern'], payload['ref']):
            break
        else:
            return False
    for pattern in filter_entry['actor_account_ids']:
        if re.search(filter_entry['pattern'], payload['sender']['id']):
            break
        else:
            return False

def validate_pr(payload, filter_groups, repo):
    #gets filenames of files that changed from base commit
    #TODO: Catch PRs with no difference in files
    diff_paths = [path.filename for path in repo.compare(
        payload['pull_request']['base']['sha'], 
        payload['pull_request']['head']['sha']
    ).files]

    valid = False
    for group in filter_groups:
        for f in group:
            valid = validate_pr_filter(f, payload, diff_paths)
            # if filter is invalid, continue to next filter group
            if valid == False:
                break
        # if all filters returned true from `validate_pr_filter()`, skip other filter groups and return true
        if valid == True:
            break
    return valid

def validate_pr_filter(filter_entry, payload, diff_paths):
    for pattern in filter_entry['file_paths']:
        for filename in diff_paths:
            if re.search(pattern, filename):
                break
            else:
                return False
    for pattern in filter_entry['commit_messages']:
        if re.search(pattern, payload['hook']['last_response']['message']):
            break
        else:
            return False
    for pattern in filter_entry['base_refs']:
        if re.search(pattern, payload['pull_request']['base']['ref']):
            break
        else:
            return False
    for pattern in filter_entry['head_refs']:
        if re.search(pattern, payload['pull_request']['head']['ref']):
            break
        else:
            return False
    for pattern in filter_entry['actor_account_ids']:
        if re.search(pattern, payload['sender']['id']):
            break
        else:
            return False
    if payload['action'] not in filter_entry['pr_actions']:
        return False
        
class LambdaException(Exception):
    pass

class ClientException(Exception):
    pass

class ServerException(Exception):
    pass