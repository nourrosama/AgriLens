"""
Standardized JSON response helpers.
"""
from flask import jsonify


def success_response(data=None, message='Success', status=200):
    """Return a success JSON envelope."""
    body = {'status': 'ok', 'message': message}
    if data is not None:
        body['data'] = data
    return jsonify(body), status


def error_response(message='An error occurred', status=400, errors=None):
    """Return an error JSON envelope."""
    body = {'status': 'error', 'message': message}
    if errors:
        body['errors'] = errors
    return jsonify(body), status
