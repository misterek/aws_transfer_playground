import json

def lambda_handler(event, context):
    """
    AWS Transfer Authentication handler.
    This function always returns a successful authentication response.
    
    :param event: The event dict that contains the parameters sent when the function is invoked.
    :param context: The context in which the function is called.
    :return: The authentication result.
    """
    # Extract username from the event
    username = event.get('username')

    # Construct the response
    response = {
        "Role": "arn:aws:iam::123456789012:role/sftp-user-role",  # Replace with actual role ARN
        "HomeDirectory": f"/home/{username}",
        "PublicKeys": []  # Add public keys if needed
    }

    # Return the authentication result
    return {
        "Version": "1.0",
        "AuthenticationResult": "Allow",
        "HomeDirectory": response["HomeDirectory"],
        "Role": response["Role"],
        "PublicKeys": response["PublicKeys"]
    }
