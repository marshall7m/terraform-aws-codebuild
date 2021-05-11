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
from typing import List


log = logging.getLogger(__name__)
log.setLevel(logging.DEBUG)
ssm = boto3.client('ssm')
cb = boto3.client('codebuild')

def lambda_handler(event, context):
    """
    Checks if a Github payload passes atleast one of the filter groups
    and if it passes, runs the associated CodeBuild project with repo specific configurations.

    Requirements:
        - Lambda Function must be invoked asynchronously
        - Payload body must be mapped to the key `body`
        - Payload headers must be mapped to the key `headers`
        - SSM Paramter Store value for Codebuild project name : Parameter key must be specified under Lambda's env var: `CODEBUILD_NAME`
        - Pre-existing SSM Paramter Store value for Github token. Parameter key must be specified under Lambda's env var: `GITHUB_TOKEN_SSM_KEY`
            (used to get filepaths that changed between head and base refs via PyGithub)
        - Filter groups, filter events, and CodeBuild override params must be specified in /opt/repo_cfg.json
    """
    payload = json.loads(event['requestPayload']['body'])
    event = event['requestPayload']['headers']['X-GitHub-Event']
    repo_name = payload['repository']['name']

    with open('/opt/repo_cfg.json') as f:
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
            sourceTypeOverride = 'GITHUB',
            **repo_cfg['codebuild_cfg']
        )
    except Exception as e:
        raise LambdaException(json.dumps(
            {
                'type': e.__class__.__name__,
                'message': str(e)
            }
        ))
    
    return {'message': 'Request was successful'}

def validate_event(event: str, valid_events: List[str]) -> None:
    """
    Checks if header event is equal to atleast one of the filter group events
    
    :param event: Github Webhook event
    :param valid_events: Distinct events from all filter groups
    """
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
        raise ClientException(
            {
                'message': 'Payload does not fulfill trigger requirements. Skipping Codebuild testing.'
            }
        )

def match_patterns(patterns, value):
    if type(value) != list:
        value = [value]
    if patterns:
        for pattern in patterns:
            for v in value:
                if re.search(pattern, v):
                    log.debug('MATCHED')
                    return True

        log.debug('NOT MATCHED')
        log.debug('patterns: %s', patterns)
        log.debug('values: %s', value)
        return False
    else:
        log.debug('No filter pattern is defined')
        return True

def lookup_value(items, value):
    if value in items:
        log.debug('TRUE')
        return True
    else:
        log.debug('NOT TRUE')
        log.debug(f'valid values: {items}')
        log.debug(f'actual value: {value}')
        return False
    
def validate_push(payload, filter_groups, repo):
    #gets filenames of files that between head commit and base commit
    diff_paths = [path.filename for path in repo.compare(payload['before'], payload['after']).files]
    
    for i, filter_entry in enumerate(filter_groups):
        log.info(f'filter group: {i+1}/{len(filter_groups)}')
        
        log.debug('filter: events')
        if not lookup_value(filter_entry['events'], 'push'):
            continue

        log.debug('filter: file_paths')
        if not match_patterns(filter_entry['file_paths'], diff_paths):
            continue

        log.debug('filter: commit_messages')
        if not match_patterns(filter_entry['commit_messages'], payload['head_commit']['message']):
            continue

        log.debug('filter: base_refs')
        if not match_patterns(filter_entry['base_refs'], payload['ref']):
            continue

        log.debug('filter: actor_account_ids')
        if not match_patterns(filter_entry['actor_account_ids'], payload['sender']['id']):
            continue
        else:
            log.debug(f'all filters are valid within group: {filter_entry}')
            if filter_entry['exclude_matched_filter']:
                log.debug('`exclude_matched_filter` is True. Excluding matched filter group')
                return False
            else: 
                return True

def validate_pr(payload, filter_groups, repo):
    #gets filenames of files that changed between PR head commit and base commit
    diff_paths = [path.filename for path in repo.compare(
        payload['pull_request']['base']['sha'], 
        payload['pull_request']['head']['sha']
    ).files]

    commit_message = repo.get_commit(sha=payload['pull_request']['head']['sha']).commit.message

    for filter_entry in filter_groups:
        
        log.debug('filter: events')
        if 'pull_request' not in filter_entry['events']:
            continue

        log.debug('filter: file_paths')
        if not match_patterns(filter_entry['file_paths'], diff_paths):
            continue

        log.debug('filter: commit_messages')
        if not match_patterns(filter_entry['commit_messages'], commit_message):
            continue

        log.debug('filter: base_refs')
        if not match_patterns(filter_entry['base_refs'], payload['pull_request']['base']['ref']):
            continue

        log.debug('filter: head_refs')
        if not match_patterns(filter_entry['head_refs'], payload['pull_request']['head']['ref']):
            continue

        log.debug('filter: actor_account_ids')
        if not match_patterns(filter_entry['actor_account_ids'], payload['sender']['id']):
            continue
        
        log.debug('filter: pr_actions')
        if not lookup_value(filter_entry['pr_actions'], payload['action']):
            continue
        else:
            log.debug(f'all filters are valid within group: {filter_entry}')
            if filter_entry['exclude_matched_filter']:
                log.debug('`exclude_matched_filter` is True. Excluding matched filter group')
                return False
            else: 
                return True

class LambdaException(Exception):
    pass

class ClientException(Exception):
    pass

class ServerException(Exception):
    pass