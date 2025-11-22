"""
Pytest configuration and shared fixtures.
"""

import sys
import os

# Add the app directory to Python path so imports work correctly
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../app'))
