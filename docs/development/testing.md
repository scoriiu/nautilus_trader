# Testing

To run Pytest with coverage

    coverage run -m pytest --ignore=tests/performance_tests/ --cov=./ --cov-report=xml
   
To annotate coverage.xml with Cython modules

    cython  --annotate-coverage coverage.xml
