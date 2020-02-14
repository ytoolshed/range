# Usage

    $ python3
    Python 3.6.8 (default, Aug  7 2019, 17:28:10) 
    [GCC 4.8.5 20150623 (Red Hat 4.8.5-39)] on linux
    Type "help", "copyright", "credits" or "license" for more information.
    >>> 
    >>> import seco.range
    >>> 
    >>> range_session = seco.range.Range(host='localhost')
    >>> range_session.expand('%{mycluster}:STABLE')
    ['hostname1', 'hostname2']
    
