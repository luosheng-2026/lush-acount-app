import '../models/category.dart';

const int incomeType = 1;
const int expenseType = 2;

const Map<String, List<String>> defaultExpenseCategories = {
  '餐饮饮食': ['早餐', '午餐', '晚餐', '零食水果', '奶茶饮品', '聚餐应酬'],
  '交通出行': ['公交地铁', '打车网约车', '电动车充电', '停车费'],
  '居家生活': ['房租', '水电燃气', '日用品', '话费充值'],
  '服饰美妆': ['衣服鞋子', '护肤品', '化妆品', '配饰'],
  '医疗健康': ['买药', '就医体检', '牙科', '保健品'],
  '人情往来': ['红包', '请客送礼', '随礼'],
  '休闲娱乐': ['游戏充值', '电影', '视频会员', '出游旅行'],
  '学习教育': ['网课', '书本文具', '考证报名费', '培训费用'],
  '其他支出': ['杂项未知开销'],
};

const Map<String, List<String>> defaultIncomeCategories = {
  '工资薪资': ['基本工资', '绩效奖金', '年终奖', '加班费'],
  '兼职副业': ['接单佣金', '劳务收入', '副业酬劳'],
  '理财收益': ['存款利息', '基金股票收益', '理财分红'],
  '转账红包': ['他人转账', '长辈红包', '还款回款'],
  '其他收入': ['赔偿退款', '物品变卖', '临时额外收益'],
};

List<AccountCategory> buildDefaultCategories() {
  final categories = <AccountCategory>[];
  var sort = 0;

  void addGroup(int type, Map<String, List<String>> source) {
    for (final entry in source.entries) {
      final parentSort = sort++;
      categories.add(AccountCategory(
        parentId: 0,
        name: entry.key,
        type: type,
        sort: parentSort,
      ));
      for (final childName in entry.value) {
        categories.add(AccountCategory(
          parentId: -parentSort - 1,
          name: childName,
          type: type,
          sort: sort++,
        ));
      }
    }
  }

  addGroup(expenseType, defaultExpenseCategories);
  addGroup(incomeType, defaultIncomeCategories);
  return categories;
}
