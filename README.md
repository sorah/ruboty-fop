# Ruboty::Fop: Ruboty handler for JAL Mileage/FOP calculator

- https://github.com/sorah/fop
- https://github.com/sorah/ruboty-fop

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'ruboty-fop'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install ruboty-fop

## Usage

```
Usage:
  ruboty fop help
  ruboty fop list {dom|intl} airports [filter]
  ruboty fop dom FROM-TO [-class CLASS] [-fare FARE] [-card CARD] [-status STATUS]
  ruboty fop intl FROM-TO [-fare FARE] [-card CARD] [-status STATUS]
  ruboty fop prefer [-class CLASS] [-fare-dom FARE] [-fare-intl FARE] [-card CARD] [-status STATUS]

Example:
  ruboty fop prefer -card global -status sapphire
  ruboty fop dom TYO-OKA -class J -fare discount
```

```
> ruboty fop list 東京
- dom: `TYO` 東京(羽田・成田)
- intl: `TYO` 東京

> ruboty fop hnd-itm
fare is required
- `normal` 運賃1（100%）: 大人普通運賃、小児普通運賃、往復割引、身体障がい者割引、介護帰省割引、JALビジネスきっぷ、eビジネス6、シャトル往復割引、離島割引、国際線航空券に含まれる日本国内区間*1など
- `fare2` 運賃2（100%）: 特別乗継割引
- `discount` 運賃3（75%）: 先得割引、スーパー先得、ウルトラ先得、乗継割引28
- `discountOther` 運賃4（75%）: 特便割引1、特便割引3、特便割引7、特便割引21、特別往復割引、株主割引
- `fare5` 運賃5（75%）: 乗継割引7
- `fare6` 運賃6（75%）: 当日シルバー割引、おともdeマイル割引*2、スカイメイト
- `inclusive` 運賃7（50%）: パッケージツアーに適用される個人包括旅行運賃など

> ruboty fop hnd-itm -fare discount -class J
TYO (東京(羽田・成田)) - OSA (大阪(伊丹・関西))
クラス J, 運賃3（75%）, - (JALカードCLUB-A会員)

*single-trip 298 miles, 476 FOP*
*round-trip 596 miles, 952 FOP*

Mileage:
- 238 ( フライトマイル 区間マイルの85% （区間マイルの75% + クラス J 分） )
- 60 ( ボーナスマイル フライトマイルの25%JALカードCLUB-A会員 )
FOP:
- 238 * 2.0


> ruboty fop hnd-sfo -fare first -card global -status sapphire
TYO (東京) - SFO (サンフランシスコ)
ファーストクラス運賃（150%）, JMBサファイア (JALグローバルクラブ会員(日本地区))

*single-trip 15775 miles, 8095 FOP*
*round-trip 31550 miles, 16190 FOP*

Mileage:
- 7695 ( フライトマイル 区間マイルの150% )
- 8080 ( ボーナスマイル フライトマイルの105%JMBサファイア会員／JALカード会員 )
FOP:
- 7695 * 1.0
- 400 ( キャンペーンボーナスポイントファーストクラス運賃 )


> ruboty fop prefer -intl-fare first -card global -status sapphire
preference updated:
{:"intl-fare"=>"first", :card=>"global", :status=>"sapphire"}


> ruboty fop hnd-syd
TYO (東京) - SYD (シドニー)
ファーストクラス運賃（150%）, JMBサファイア (JALグローバルクラブ会員(日本地区))

*single-trip 14955 miles, 11342 FOP*
*round-trip 29910 miles, 22684 FOP*

Mileage:
- 7295 ( フライトマイル 区間マイルの150% )
- 7660 ( ボーナスマイル フライトマイルの105%JMBサファイア会員／JALカード会員 )
FOP:
- 7295 * 1.5
- 400 ( キャンペーンボーナスポイントファーストクラス運賃 )
```


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/sorah/ruboty-fop.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
