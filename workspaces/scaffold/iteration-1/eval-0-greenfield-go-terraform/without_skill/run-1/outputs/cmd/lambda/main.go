// Command lambda runs the service behind AWS Lambda.
//
// It reuses the shared HTTP handler by replaying each API Gateway request
// through an in-process httptest recorder, so the same routing/logic backs
// both the standalone server (cmd/api) and the Lambda deployment.
package main

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"

	"github.com/Medprev/go-api-service/internal/handler"
)

type adapter struct {
	h http.Handler
}

func (a adapter) handle(
	_ context.Context,
	req events.APIGatewayV2HTTPRequest,
) (events.APIGatewayV2HTTPResponse, error) {
	method := req.RequestContext.HTTP.Method
	if method == "" {
		method = http.MethodGet
	}

	httpReq := httptest.NewRequest(method, req.RawPath, strings.NewReader(req.Body))
	for k, v := range req.Headers {
		httpReq.Header.Set(k, v)
	}

	rec := httptest.NewRecorder()
	a.h.ServeHTTP(rec, httpReq)

	headers := make(map[string]string, len(rec.Header()))
	for k := range rec.Header() {
		headers[k] = rec.Header().Get(k)
	}

	return events.APIGatewayV2HTTPResponse{
		StatusCode: rec.Code,
		Headers:    headers,
		Body:       rec.Body.String(),
	}, nil
}

func main() {
	a := adapter{h: handler.New()}
	lambda.Start(a.handle)
}
