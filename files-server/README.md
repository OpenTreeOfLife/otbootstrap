# Setting up and maintaining the 'files server' on Amazon S3

There is an assumption on this site that files (other than
`index.html` and other 'glue' files) are not updated in place.  When a
new file or directory is added it gets a new name that includes a
version number or date.

## Access to S3

Make sure you have an S3 account with rights to the
files.opentreeoflife.org bucket, and set up the `~/.aws/credentials`
and `~/.aws/config` files per instructions at Amazon.

Install the 'aws' command per instructions.  The following is what I
used on a Macbook:

```
pip install --upgrade --user awscli  
export PYTHON_BIN=~/Library/Python/2.7/bin
```

## Set up http://files.opentreeoflife.org web hosting at S3

This involves:
 1. configuring the bucket for hosting
 1. setting up name service for the files.opentreeoflife.org subdomain
    with Amazon
 1. establishing an A record for the subdomain using Amazon's Route 53
    'alias' feature
 1. updating host records at Namecheap.
The instructions on the AWS site are pretty good.
Don't add an A record at Namecheap; only add a set of NS records as
directed.  Note that we are _not_ doing a domain (registrar) transfer, only
subdomain name server redirection.  The instructions do not cover this
case, but if you have an understanding of DNS, it's not hard.

## Keeping track of metadata

An unfortunate aspect of the `aws cp` and `aws sync` commands is that
they do not preserve file modification date/time metadata.  It is
useful to get the file write dates correct in each directory's
index.html.  Therefore a script is provided for maintaining this
metadata.

The write dates are stored in a file `.write_dates.json` in each
directory and is updated using the `capture_write_dates.py` script in
either of two ways:

 * `.write_dates.json` can be generated afresh from a local mirror of
   a directory on the files.opentreeoflife.org web site, when it is
   absent or when the `--refresh` flag is given.

 * An existing `.write_dates.json` can be updated from a local mirror
   directory, even if the mirror does not contain the entire contents
   of the directory.  Metadata for unmirrored files will be carried
   forward, and metadata for local files will be added or updated as
   necesary.

If the file's size does not change, then its write date in
`.write_dates.json` is left unmodified.

To generate all of the `.write_dates.json` files locally, based on a
local mirror or previous instantiation of the site (e.g. the one on
varela.csail.mit.edu):

```
cd files.opentreeoflife.org     # local mirror  
find . -type d -exec python {path-to-here}/capture_write_dates.py {} \;
```

where `{path-to-here}` is the path to the directory containing this
README.

## Creating index.html files

S3 does not automatically generate directory indexes, so we have to do
this explicitly.  One solution is
[here](https://github.com/rufuspollock/s3-bucket-listing) but the
difficulty is that the wrong file modification dates will be
shown - the script shows the dates stored on S3, but we want the
actual dates from the origin of the file.

The `prepare_index.py` script creates an `index.html` file using the
data in the `.write_dates.json` (see above).

To generate all of the index.html files:

```
cd files.opentreeoflife.org     # local mirror  
find . -type d -exec python {path-to-here}/prepare_index.py {} \;
```

If an index.html already exists that was not generated by the script,
then it is not overwritten.

## Populating S3

To copy all local files (mirror or varela.csail.mit.edu) to S3:

```
cd files.opentreeoflife.org    # local mirror  
$PYTHON_BIN/aws s3 sync . s3://files.opentreeoflife.org/
```

`sync` documentation is [here](http://docs.aws.amazon.com/cli/latest/reference/s3/sync.html).

It can take a long time to copy 11G.
If interrupted, the `sync` can be tried again, and files that have aleady
been copied are not copied redundantly.

## Maintenance

When there are new files to copy to S3 (e.g. a taxonomy or synthesis
release):

1. Place the new file(s) correctly in a local mirror of the site.
   (This is not strictly necessary, but it makes things easier.)
1. Update the `index.html` for the directory containing the new file,
   and create an `index.html` for each new directory (as needed).
   There are several ways to do this:
    * If the local mirror of the parent directory is complete and the
       write dates on the local files are correct, then re-run (or run)
       `capture_write_dates.py` and then `prepare_index.py`, as above.
    * Or, retrieve `index.html` from S3, and edit it manually to add the
       new file(s).  Create new index.html files for new directories.
    * Or, retrieve `.write_dates.json` from S3, edit it to add the new file(s), and
       re-run `prepare_index.py` to update `index.html`.
    * Or, decide that there is no need for an `index.html` and just
      delete it or replace with a stub.
1. Copy the new file(s), as well as the updated `index.html` and
  `.write_dates.json`, to S3 using `aws s3 cp` or `aws s3 sync`.

Don't worry too much about the `"timestamp"` field in `.write_dates.json`.
It's not currently used for anything, and can be omitted.

For deletion: Do it manually using `aws s3 rm` or `aws s3 rm ...
--recursive` or `aws s3 sync ... --delete`, and edit or
regenerate the `.write_dates.json` and/or `index.html` files.

## Redirections

Documentation [here](http://docs.aws.amazon.com/AmazonS3/latest/dev/how-to-page-redirect.html)

Make OTT version 3.0 be the current version of OTT:

```
echo foo >dummy.tmp  
$PYTHON_BIN/aws s3 cp dummy.tmp s3://files.opentreeoflife.org/ott/current --website-redirect /ott/ott3.0
```

Similarly for synthesis 9.0:

```
echo foo >dummy.tmp  
$PYTHON_BIN/aws s3 cp dummy.tmp s3://files.opentreeoflife.org/synthesis/current --website-redirect /synthesis/synthesis9.0
```
