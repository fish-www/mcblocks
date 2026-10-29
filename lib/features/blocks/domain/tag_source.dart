/// 标签来源。优先级 `user > vanilla > auto`，低优先级不覆盖高优先级。
enum TagSource {
  auto('auto'),
  vanilla('vanilla'),
  user('user');

  const TagSource(this.value);

  final String value;

  int get priority => switch (this) {
    TagSource.auto => 0,
    TagSource.vanilla => 1,
    TagSource.user => 2,
  };

  static TagSource parse(String value) => switch (value) {
    'user' => TagSource.user,
    'vanilla' => TagSource.vanilla,
    _ => TagSource.auto,
  };
}
