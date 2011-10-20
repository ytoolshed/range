from distutils.core import setup, Extension

module1 = Extension('secorange',
                    libraries = ['range', 'pcre'],
                    library_dirs = ['/usr/local/lib'],
                    sources = ['secorange.c'])

setup (name = 'SecoRange',
       version = '2.0',
       description = 'Seco Range package',
       author = 'Daniel Muino, Evan Miller',
       author_email = 'dmuino@yahoo-inc.com,eam@yahoo-inc.com',
       long_description = '''
Deal with seco ranges
''',
       ext_modules = [module1])

