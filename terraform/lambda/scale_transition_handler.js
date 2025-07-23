// Lambda function to handle scale transition
// This function is triggered by CloudWatch alarms via SNS
// It updates the deployment scale parameter in SSM

const AWS = require('aws-sdk');

exports.handler = async (event, context) => {
  console.log('Received event:', JSON.stringify(event, null, 2));
  
  // Initialize AWS clients
  const ssm = new AWS.SSM({ region: process.env.REGION });
  const cloudwatch = new AWS.CloudWatch({ region: process.env.REGION });
  const sns = new AWS.SNS({ region: process.env.REGION });
  
  try {
    // Parse the SNS message
    const message = JSON.parse(event.Records[0].Sns.Message);
    const alarmName = message.AlarmName;
    const newState = message.NewStateValue;
    
    // Only process if the alarm is in ALARM state
    if (newState !== 'ALARM') {
      console.log(`Alarm ${alarmName} is in ${newState} state. No action needed.`);
      return {
        statusCode: 200,
        body: JSON.stringify({ message: `Alarm ${alarmName} is in ${newState} state. No action needed.` })
      };
    }
    
    // Get the current deployment scale from SSM
    const currentScaleParam = await ssm.getParameter({
      Name: '/infrastructure/deployment_scale',
      WithDecryption: false
    }).promise();
    
    const currentScale = currentScaleParam.Parameter.Value;
    console.log(`Current deployment scale: ${currentScale}`);
    
    // Determine the new scale based on the alarm name
    let newScale = currentScale;
    
    if (alarmName === 'scale-up-small-to-medium' && currentScale === 'small') {
      newScale = 'medium';
    } else if (alarmName === 'scale-up-medium-to-large' && currentScale === 'medium') {
      newScale = 'large';
    } else if (alarmName === 'scale-down-medium-to-small' && currentScale === 'medium') {
      newScale = 'small';
    } else if (alarmName === 'scale-down-large-to-medium' && currentScale === 'large') {
      newScale = 'medium';
    }
    
    // If the scale hasn't changed, no action needed
    if (newScale === currentScale) {
      console.log(`No scale change needed. Remaining at ${currentScale}.`);
      return {
        statusCode: 200,
        body: JSON.stringify({ message: `No scale change needed. Remaining at ${currentScale}.` })
      };
    }
    
    // Update the deployment scale in SSM
    await ssm.putParameter({
      Name: '/infrastructure/deployment_scale',
      Value: newScale,
      Type: 'String',
      Overwrite: true
    }).promise();
    
    console.log(`Updated deployment scale from ${currentScale} to ${newScale}`);
    
    // Send notification about the scale change
    await sns.publish({
      TopicArn: process.env.SNS_TOPIC_ARN || '',
      Subject: `Deployment Scale Changed: ${currentScale} to ${newScale}`,
      Message: JSON.stringify({
        previousScale: currentScale,
        newScale: newScale,
        timestamp: new Date().toISOString(),
        reason: `Alarm ${alarmName} triggered the scale change`,
        metrics: {
          alarmName: alarmName,
          alarmDescription: message.AlarmDescription,
          newStateReason: message.NewStateReason
        }
      })
    }).promise();
    
    return {
      statusCode: 200,
      body: JSON.stringify({ 
        message: `Successfully updated deployment scale from ${currentScale} to ${newScale}` 
      })
    };
  } catch (error) {
    console.error('Error:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: error.message })
    };
  }
};