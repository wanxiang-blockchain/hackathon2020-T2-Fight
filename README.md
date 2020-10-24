# wxhackathon2020
Hackers of Wanxiang Blockchain Hackathon


## Preinstall MacOS

```bash
brew install ruby
brew install node
brew install yarn
gem install bundler
echo 'gem: "--no-document"' >> ~/.gemrc
```

## Regenerate master.key (skip if you have)

```bash
rm config/credentials.yml.enc
bin/rails credentials:edit
# copy credentials.yml.example file content and paste as new line
```

## Link the master.key (using above if you don't)

```bash
ln -s /Users/[user_name]/.ssh/hackathon2020-T2-Fight_master.key config/master.key
```

## Development prepare

```bash
bin/setup
```

## Run test

```bash
bin/rake
```

## Start development

```bash
bin/rails s
```
