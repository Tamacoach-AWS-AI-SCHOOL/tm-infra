"use strict";

exports.handler = (event, context, callback) => {
  const request = event.Records[0].cf.request;
  const hostHeader = request.headers.host && request.headers.host[0] ? request.headers.host[0].value : "";

  let targetDomain = "api.tamacoach.net";
  if (hostHeader === "stage.tamacoach.net") {
    targetDomain = "api-stage.tamacoach.net";
  }

  request.origin = {
    custom: {
      domainName: targetDomain,
      port: 443,
      protocol: "https",
      path: "",
      sslProtocols: ["TLSv1.2"],
      readTimeout: 30,
      keepaliveTimeout: 5,
      customHeaders: {}
    }
  };

  request.headers.host = [{ key: "host", value: targetDomain }];
  callback(null, request);
};
