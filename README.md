# Persona

**Warning: unmaintained since 2004!**

Persona is personal pages generator. See demonstration example in demo-src
subdirectory. Script demo.sh will create directory demo with generated demo
pages.

`Usage: ./persona.pl description_file destination_dir logfile languages...`

- description_file is described later
- destination_dir will be created if not exists
- logfile contains MD5's of all generated files
- languages is one or more language codes (like cs, en, de etc.) for which
pages should be created

Description file is normal Perl source. There must be definition of hash
'resource' and optionally definition of subs to be used in page templates.

Resources are central point of Persona. Each resource has type. Resource
types starting with 'x' are for use by user, others are internal. These are:
global, file, dir and template. Each resource of internal type is processed
when output is generated.

All resources except for global resource and all data keys can have language
versions. Data keys with explicit languages have '_CODE' postfix where CODE
is language code. Resource languages are indicated by presence of
'languages' data key array with language codes this resource provides.

Data keys can be normal scalars, arrays, hashes or subroutines. Subroutines
are executed each time the value is requested and as arguments have resource
name, key name and current language.

Global resource can be only one and must be named 'global'. It contains
defaults for other resources' data.

File resource has data key hash 'source' where 'file' is local file path and
'dest' is destination file path. When processed it will copy file to dest if
dest does not exist or has different MD5.

Dir resource has data key hash 'source' where 'file' is local directory path
and 'dest' is destination directory path. When processed it will recursively
copy files from file to dest if destination files does not exist or have
different MD5. In 'ignore' there could be regexp which matches file names
not to copy.

Template resource is the same as file resource except that input file is
processed as template. That means sequences <? ...code... /?> and <?
...code... ?>...something...<?/?> are replaced with returned value from code
execution (code is of course Perl). 'code' and 'something' may span multiple
lines. Destination is overwritten only if it does not exist or has different
MD5. If global data key 'comparator_regexp' exists template output and
destination will be processed against substitute operator s/REGEXP//g before
computing MD5s.

Template code can use subroutines defined in description file and these
builtins (processing is stopped if they are passed incorrect arguments like
missing resource or data key):

`location ([resource [, language]])`

- returns destination location of resource (default is current) in given
language (default is current) relative to current resource's location

`abs_location (prefix, [resource [, language]])`

- returns destination location of resource (default is current) in given
language (default is current) relative to destination directory with
prepended prefix

`file ([resource [, language]])`

- returns source location of resource (default is current) in given
language (default is current)

`language ()`

- returns current language

`resource ()`

- returns current resource name

`data (name, [resource [, language]])`

- returns data key value for given resource (default is current) in given
language (default is current); if language version is not found (like
KEY_LANG), no-language version is taken (like KEY); if it is not found in
given resource, global resource is used

`matching (name, value)`

- returns all resources whose data key name has given value; resources with
data key 'hidden' set to '1' are omited; returned resources are ordered
according to 'resource_order' data key (those not mentioned in there go
last)

`respath ([resource])`

- returns list of parent resources (parent resource is specified in 'parent'
data key which can not have language versions)

`reslang ([resource])`

- returns available languages for given resource (default is current) as
list

`include (resource)`

- includes given resource's output (must be of type file or template)

Data key subroutines can not call those mentioned above, but can call
get_data_key (resource, key, language) which is similar to data (), but does
not die if key does not exist.
