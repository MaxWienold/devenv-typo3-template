# TYPO3 CMS Devenv template

Get going quickly with TYPO3 CMS.

## Why not ddev?
I tried ddev and had some issues under nixOS. 
For me, devenv is more transparent and therefore more customizable.

## How To Use
You can either start a project manually with 
```bash
composer create-project typo3/cms-base-distribution [version] 
```
then copy this repo into the directory and change the values in devenv.nix. When the environment is started with ``devenv up [-d]``, you can setup typo3 via your preferred method.

Or you can start ``configure.sh``. This will ask for these values and do the rest for you. Please make sure that this is run against an empty database state (.devenv/state/mysql)
