# LUKS Helper Yay :D

## What it does
- Setup a LUKS drive.
- It conveniently and automatically mounts your LUKS drive from said setup (doesn't work otherwise).

## How it works
- It setup a LUKS drive with `--type luks2`.
- It then creates a keyfile for said LUKS drive, backup the header, and verify with b3sum, then store all of them in the USB stick of choice.
- It stores drives by UUID so you don't have to worry about name change.

## Requirements
- Root permission.
- 2 drives, 1 for LUKS, 1 for the keyfile.

## Why
- Passphrases are BORING!

## How to use
- To make a LUKS drive:
```
$ make_luks.sh
```

- To (re)generate a config file:
```
$ main.sh init
```

- To open a LUKS drive.
```
$ main.sh open
```

- To close a LUKS drive.
```
$ main.sh close 
```
