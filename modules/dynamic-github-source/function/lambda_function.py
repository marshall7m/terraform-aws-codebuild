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
log.setLevel(logging.DEBUG)
ssm = boto3.client('ssm')
cb = boto3.client('codebuild')
def lambda_handler(event, context):
    payload = json.loads(event['requestPayload']['body'])
    event = event['requestPayload']['headers']['X-GitHub-Event']
    repo_name = payload['repository']['name']

    with open('/opt/repo_cfg.json') as f:
      #get filter groups associated with target repository
      repo_cfg = json.load(f)[repo_name]

    filter_groups = repo_cfg['filter_groups']
    valid_events = repo_cfg['events']

    log.info(f'Triggered Repo: {repo_name}')
    log.info(f'Triggered Event: {event}')

    log.info(f'Valid Events: {event}')
    log.info(f'Repo Filter Groups: {filter_groups}')

    log.info('Validating event')
    validate_event(event, valid_events)

    log.info('Validating payload')
    validate_payload(payload, event, filter_groups)

    log.info(f'Starting CodeBuild project: {os.environ["CODEBUILD_NAME"]}')
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
                'message': f'{event} is not a valid event according to the Terraform module that created the webhook'
            }
        )

def validate_payload(payload, event, filter_groups):
    github_token = ssm.get_parameter(Name=os.environ['GITHUB_TOKEN_SSM_KEY'], WithDecryption=True)['Parameter']['Value']
    gh = Github(github_token)
    repo = gh.get_repo(payload['repository']['full_name'])
    
    if event == 'pull_request':
        log.debug('Running validate_pr()')
        valid = validate_pr(payload, filter_groups, repo)
    elif event == 'push':
        log.debug('Running validate_push()')
        valid = validate_push(payload, filter_groups, repo)
    else:
        raise ClientException(
            {
                'message': f'Handling for event: {event} has not been created'
            }
        )

    if valid:
        log.info('Payload fulfills atleast one filter group')
    else:
        log.info('Payload does not fulfill any of the filter groups requirements')
        raise ClientException(
            {
                'message': 'Payload does not fulfill trigger requirements. Skipping Codebuild testing.'
            }
        )

def valid_filepaths(filenames, pattern):
    """Used as sub-function within `validate_*_filter() to create a double `break` if filename matches pattern"""
    for filename in filenames:
        log.debug(f'filename: {filename}')
        if match_patterns([pattern], filename):
            return True
    return False

def match_patterns(patterns, value):
    if patterns:
        for i, pattern in enumerate(patterns):
            if re.search(pattern, value):
                log.debug('MATCHED')
                return True
            if i+1 == len(patterns):
                log.debug('NOT MATCHED')
                log.debug('patterns: %s', patterns)
                log.debug('values: %s', value)
                return False
    else:
        log.debug('No filter pattern is defined')
        return True


def validate_push(payload, filter_groups, repo):
    #gets filenames of files that between head commit and base commit
    diff_paths = [path.filename for path in repo.compare(payload['before'], payload['after']).files]
    
    for group in filter_groups:
        if 'push' in group['events']:
            for filter_entry in group:
                if filter_entry['event']
                log.debug('filter: file_paths')
                for pattern in filter_entry['file_paths']:
                    if valid_filepaths(diff_paths, pattern):
                        break

                log.debug('filter: commit_messages')
                if not match_patterns(filter_entry['commit_messages'], payload['head_commit']['message']):
                    break

                log.debug('filter: base_refs')
                if not match_patterns(filter_entry['base_refs'], payload['ref']):
                    break

                log.debug('filter: actor_account_ids')
                if not match_patterns(filter_entry['actor_account_ids'], payload['sender']['id']):
                    break
                else:
                    log.debug(f'all filters are valid within group: {group}')
                    if filter_entry['exclude_matched_filter']:
                        log.debug('`exclude_matched_filter` is True. Excluding matched filter group')
                        return False
                    else: 
                        True

def validate_pr(payload, filter_groups, repo):
    #gets filenames of files that changed between PR head commit and base commit
    diff_paths = [path.filename for path in repo.compare(
        payload['pull_request']['base']['sha'], 
        payload['pull_request']['head']['sha']
    ).files]

    commit_message = repo.get_commit(sha=payload['pull_request']['head']['sha']).commit.message

    valid = False
    for group in filter_groups:
        for filter_entry in group:
            
            log.debug('filter: file_paths')
            for pattern in filter_entry['file_paths']:
                if valid_filepaths(diff_paths, pattern):
                    break

            log.debug('filter: commit_messages')
            if not match_patterns(filter_entry['commit_messages'], commit_message):
                break

            log.debug('filter: base_refs')
            if not match_patterns(filter_entry['base_refs'], payload['pull_request']['base']['ref']):
                break

            log.debug('filter: head_refs')
            if not match_patterns(filter_entry['head_refs'], payload['pull_request']['head']['ref']):
                break

            log.debug('filter: actor_account_ids')
            if not match_patterns(filter_entry['actor_account_ids'], payload['sender']['id']):
                break
            
            log.debug('filter: pr_actions')
            if payload['action'] not in filter_entry['pr_actions']:
                log.debug('NOT MATCHED')
                log.debug(f'valid values: {filter_entry["pr_actions"]}')
                log.debug(f'actual value: {payload["action"]}')
                break
            else:
                log.debug(f'all filters are valid within group: {group}')
                if filter_entry['exclude_matched_filter']:
                    log.debug('`exclude_matched_filter` is True. Excluding matched filter group')
                    return False
                else: 
                    True

class LambdaException(Exception):
    pass

class ClientException(Exception):
    pass

class ServerException(Exception):
    pass