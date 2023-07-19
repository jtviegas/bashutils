![release](https://github.com/jtviegas/bashutils/workflows/release/badge.svg?branch=master)
# bashutils
bash scripting utils include file 

...or how to use an `helper.sh` script powered by a `.bashutils` include file loaded with handy functions

## usage

* download the `helper.sh` 
    script:
    
    `wget https://raw.githubusercontent.com/jtviegas/bashutils/master/helper.sh`
* make it executable: `chmod +x helper.sh`
* update bashutils include file: `./helper.sh update_bashutils`


you should now see this when running `./helper.sh`:
```
 [DEBUG] Wed Jul 19 07:57:19 CEST 2023 ... 1:  2:  3:  4:  5:  6:  7:  8:  9:
  usage:
  helper.sh { package }

      - package: tars the bashutils include file
      - update_bashutils: updates the include '.bashutils' file
```   

and your local folder should have now:
```
% ls -altr
total 24
drwxr-xr-x  4 jotvi  staff   128 Jul 19 07:48 ..
-rw-r--r--  1 jotvi  staff     0 Jul 19 07:51 .variables
-rw-r--r--  1 jotvi  staff     0 Jul 19 07:51 .local_variables
-rw-r--r--  1 jotvi  staff     0 Jul 19 07:51 .secrets
-rwxr-xr-x  1 jotvi  staff  4974 Jul 19 07:55 .bashutils
-rwxr-xr-x  1 jotvi  staff  2624 Jul 19 07:55 helper.sh
drwxr-xr-x  7 jotvi  staff   224 Jul 19 07:56 .
```
## Notes

the script tries to include variables and secrets into the running environment through the files `.variables`, `.local_variables` (_for local user specific variables, should not be included in versioning_) and `.secrets` (_should not be included in versioning_) in this order:
```
export FILE_VARIABLES=${FILE_VARIABLES:-".variables"}
export FILE_LOCAL_VARIABLES=${FILE_LOCAL_VARIABLES:-".local_variables"}
export FILE_SECRETS=${FILE_SECRETS:-".secrets"}

if [ ! -f "$this_folder/$FILE_VARIABLES" ]; then
  warn "we DON'T have a $FILE_VARIABLES variables file - creating it"
  touch "$this_folder/$FILE_VARIABLES"
else
  . "$this_folder/$FILE_VARIABLES"
fi

if [ ! -f "$this_folder/$FILE_LOCAL_VARIABLES" ]; then
  warn "we DON'T have a $FILE_LOCAL_VARIABLES variables file - creating it"
  touch "$this_folder/$FILE_LOCAL_VARIABLES"
else
  . "$this_folder/$FILE_LOCAL_VARIABLES"
fi

if [ ! -f "$this_folder/$FILE_SECRETS" ]; then
  warn "we DON'T have a $FILE_SECRETS secrets file - creating it"
  touch "$this_folder/$FILE_SECRETS"
else
  . "$this_folder/$FILE_SECRETS"
fi
``` 
