exports.handler = (event, context, cb) => {
    console.log(event.Records[0].Sns.Message);
    console.log(context);
    cb(null, "soy el response");
}