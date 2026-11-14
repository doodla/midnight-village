// The mock HTTP client lives under integration_test/helpers/ so that the web
// integration build (flutter drive), whose app root is integration_test/, can
// import it; a relative import out of that root does not compile. Unit and
// widget tests import it from here.
export '../../integration_test/helpers/mock_http_client.dart';
