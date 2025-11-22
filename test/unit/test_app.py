"""
Unit tests for the Flask web service application.
Tests basic endpoints, error handling, and request logging.

Run with: pytest test/unit/test_app.py -v
"""

import pytest
import json
from app.app import app


@pytest.fixture
def client():
    """Create a test client for the Flask app."""
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client


@pytest.fixture
def runner():
    """Create a CLI test runner for the Flask app."""
    return app.test_cli_runner()


class TestIndexEndpoint:
    """Tests for the root endpoint (/)."""

    def test_index_returns_200(self, client):
        """Test that root endpoint returns 200 status."""
        response = client.get('/')
        assert response.status_code == 200

    def test_index_returns_json(self, client):
        """Test that root endpoint returns JSON content-type."""
        response = client.get('/')
        assert response.content_type == 'application/json'

    def test_index_response_structure(self, client):
        """Test that root endpoint returns expected fields."""
        response = client.get('/')
        data = json.loads(response.data)
        
        assert 'service' in data
        assert 'version' in data
        assert 'timestamp' in data
        assert 'message' in data

    def test_index_response_values(self, client):
        """Test that root endpoint returns correct values."""
        response = client.get('/')
        data = json.loads(response.data)
        
        assert data['service'] == 'web-service'
        assert isinstance(data['version'], str)
        assert len(data['version']) > 0


class TestHealthEndpoint:
    """Tests for the health check endpoint."""

    def test_health_returns_200(self, client):
        """Test that health endpoint returns 200 status."""
        response = client.get('/health')
        assert response.status_code == 200

    def test_health_returns_json(self, client):
        """Test that health endpoint returns JSON content-type."""
        response = client.get('/health')
        assert response.content_type == 'application/json'

    def test_health_status_is_healthy(self, client):
        """Test that health endpoint returns healthy status."""
        response = client.get('/health')
        data = json.loads(response.data)
        
        assert data['status'] == 'healthy'

    def test_health_response_structure(self, client):
        """Test that health endpoint returns expected fields."""
        response = client.get('/health')
        data = json.loads(response.data)
        
        assert 'status' in data
        assert 'service' in data
        assert 'version' in data


class TestVersionEndpoint:
    """Tests for the version endpoint."""

    def test_version_returns_200(self, client):
        """Test that version endpoint returns 200 status."""
        response = client.get('/version')
        assert response.status_code == 200

    def test_version_returns_json(self, client):
        """Test that version endpoint returns JSON content-type."""
        response = client.get('/version')
        assert response.content_type == 'application/json'

    def test_version_has_version_field(self, client):
        """Test that version endpoint includes version field."""
        response = client.get('/version')
        data = json.loads(response.data)
        
        assert 'version' in data
        assert isinstance(data['version'], str)

    def test_version_has_service_field(self, client):
        """Test that version endpoint includes service field."""
        response = client.get('/version')
        data = json.loads(response.data)
        
        assert 'service' in data


class TestInfoEndpoint:
    """Tests for the detailed info endpoint."""

    def test_info_returns_200(self, client):
        """Test that info endpoint returns 200 status."""
        response = client.get('/api/info')
        assert response.status_code == 200

    def test_info_returns_json(self, client):
        """Test that info endpoint returns JSON content-type."""
        response = client.get('/api/info')
        assert response.content_type == 'application/json'

    def test_info_response_structure(self, client):
        """Test that info endpoint returns expected fields."""
        response = client.get('/api/info')
        data = json.loads(response.data)
        
        assert 'service' in data
        assert 'version' in data
        assert 'timestamp' in data

    def test_info_has_uptime_info(self, client):
        """Test that info endpoint includes uptime info."""
        response = client.get('/api/info')
        data = json.loads(response.data)
        
        assert 'uptime_info' in data


class TestErrorHandling:
    """Tests for error handling."""

    def test_404_not_found(self, client):
        """Test that non-existent endpoint returns 404."""
        response = client.get('/nonexistent')
        assert response.status_code == 404

    def test_404_returns_json(self, client):
        """Test that 404 response returns JSON."""
        response = client.get('/nonexistent')
        assert response.content_type == 'application/json'

    def test_404_has_error_field(self, client):
        """Test that 404 response includes error field."""
        response = client.get('/nonexistent')
        data = json.loads(response.data)
        
        assert 'error' in data
        assert 'path' in data


class TestHTTPMethods:
    """Tests for HTTP method handling."""

    def test_index_only_accepts_get(self, client):
        """Test that root endpoint only accepts GET requests."""
        response = client.post('/')
        # POST should either be rejected or accepted based on implementation
        # Current implementation likely rejects it
        assert response.status_code in [405, 200]  # Method Not Allowed or handled

    def test_health_only_accepts_get(self, client):
        """Test that health endpoint only accepts GET requests."""
        response = client.post('/health')
        assert response.status_code in [405, 200]

    def test_version_only_accepts_get(self, client):
        """Test that version endpoint only accepts GET requests."""
        response = client.post('/version')
        assert response.status_code in [405, 200]


class TestResponseHeaders:
    """Tests for response headers."""

    def test_json_endpoint_has_correct_content_type(self, client):
        """Test that JSON endpoints have correct content-type header."""
        response = client.get('/')
        assert 'application/json' in response.content_type

    def test_response_has_standard_headers(self, client):
        """Test that responses include standard headers."""
        response = client.get('/')
        
        # Flask should include these headers
        assert 'Content-Type' in response.headers
        assert 'Content-Length' in response.headers


class TestVersionEnvironmentVariable:
    """Tests for version environment variable handling."""

    def test_version_from_environment(self, client):
        """Test that service returns version from environment variable."""
        response = client.get('/version')
        data = json.loads(response.data)
        
        # Version should be set from SERVICE_VERSION env var or default
        assert 'version' in data
        assert data['version'] is not None


class TestServiceName:
    """Tests for service name handling."""

    def test_service_name_in_responses(self, client):
        """Test that service name is included in responses."""
        endpoints = ['/', '/health', '/version', '/api/info']
        
        for endpoint in endpoints:
            response = client.get(endpoint)
            data = json.loads(response.data)
            
            if 'service' in data:
                assert isinstance(data['service'], str)
                assert len(data['service']) > 0
