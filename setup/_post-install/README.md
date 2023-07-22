## Post-install Set Up Scripts

Scripts expected to be used pretty much directly after installation of an OS, likely before even cloning this 
repository. The executable bit is purposefully not set to avoid accidentally running these scripts.

## Expected use:
```shell
$ sudo bash -c "$(wget -qO- 'https://raw.githubusercontent.com/rvenutolo/scripts/main/setup/_post-install/script.sh')"
$ sudo bash -c "$(curl -fsLS 'https://raw.githubusercontent.com/rvenutolo/scripts/main/setup/_post-install/script.sh')"
```
