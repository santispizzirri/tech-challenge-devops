"""
Pytest configuration and shared fixtures.
"""

import sys
import os

# Add the project root to Python path so imports work correctly
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, project_root)
