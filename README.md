# SimSig Gateway Control
Simple Ruby application that uses the [SimSig](https://simsig.co.uk/)
[Interface Gateway](https://www.simsig.co.uk/Wiki/Show?page=usertrack:interface_gateway) to connect to a running
simulation and issues reminders to close level crossings or takes control of them for you. See the
[forum post](https://www.simsig.co.uk/Forum/ThreadView/56269?postId=161283) for background.

## Install
Prerequisites: Ruby & Bundler

```
git clone https://github.com/ArtOfCode-/simsig
cd simsig
bundle install
```

Copy `config/credentials.example.yml` to `config/credentials.yml` and enter your SimSig username and password.

### WSL note
If you're running this on WSL on Windows, you'll also need to use WSL mirrored networking mode, or change the hostname
in your configuration to `<computername>.local` (i.e. if your computer name is `MYPC`, you'd use `MYPC.local`).

## Usage
```
ruby simsig.rb [options] <area>
```

Currently the only option is `-v` for verbose debug logging. You probably don't need this.

`<area>` is mandatory and must be the SimSig-internal name of the sim you're running, i.e. `sheffield` or `swindid`,
etc.

You'll also need an area configuration file such as `config/sheffield.yml` that specifies the mode to use and the
trigger points for crossings. Sheffield is provided as an example. Triggers may be signal IDs or route IDs. The `mode`
key can be either `control` or `reminder` and specifies whether the application will close crossings for you or just
output a reminder for you to do it.

## Development/Contributing
If you want to! PRs are welcome, particularly with additional area configuration files.

## License
MIT license. See `LICENSE`.
