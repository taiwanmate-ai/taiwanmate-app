// ════════════════════════════════════════════════════════════════
// JOURNEY DATA — NỘI DUNG CÁC NGÀY
//
// CÁCH THÊM NỘI DUNG MỚI (tháng sau, chủ đề mới):
//   1. Viết thêm 1 khối: const List<Day> tenMoi = [ Day(...), ... ];
//   2. Thêm "...tenMoi," vào danh sách journeyDays bên dưới.
//   KHÔNG sửa journey.dart, KHÔNG sửa các khối cũ.
// ════════════════════════════════════════════════════════════════

import 'journey.dart';

const List<Day> week1 = [

  // ───── NGÀY 1: Chào hỏi & làm quen ─────
  Day(day: 1, emoji: '👋',
    titleVi: 'Lần đầu chào hỏi', titleEn: 'First Greetings',
    sceneVi: 'Bạn vừa đặt chân đến Đài Loan, kéo vali vào ký túc xá. Một người Đài Loan ngồi ở sảnh ngẩng lên, mỉm cười. Tim đập nhanh — đây là lần đầu bạn nói tiếng Trung với người thật...',
    sceneEn: 'You just arrived in Taiwan, dragging your suitcase into the dorm. A Taiwanese person in the lobby looks up and smiles. Your heart races — your first time speaking Chinese with a real person...',
    equips: [
      Equip(zh: '你好', en: 'Hello', py: 'nǐ hǎo', ipa: '/həˈloʊ/', vi: 'Xin chào', variants: [
        Variant(zh: '嗨', en: 'Hi', py: 'hāi', note: 'thân mật'),
        Variant(zh: '早安', en: 'Good morning', py: 'zǎo ān', note: 'buổi sáng'),
        Variant(zh: '你好嗎', en: 'How are you?', py: 'nǐ hǎo ma', note: 'hỏi thăm'),
      ]),
      Equip(zh: '我叫阿海', en: "I'm Hai", py: 'wǒ jiào ā hǎi', ipa: '/aɪm/', vi: 'Tôi tên là Hải', variants: [
        Variant(zh: '我的名字是阿海', en: 'My name is Hai', py: 'wǒ de míng zì shì ā hǎi', note: 'trang trọng'),
        Variant(zh: '叫我阿海就好', en: 'Just call me Hai', py: 'jiào wǒ ā hǎi jiù hǎo', note: 'thân thiện'),
      ]),
      Equip(zh: '我是越南人', en: 'I am Vietnamese', py: 'wǒ shì yuè nán rén', ipa: '/aɪ æm/', vi: 'Tôi là người Việt Nam', variants: [
        Variant(zh: '我從越南來', en: 'I come from Vietnam', py: 'wǒ cóng yuè nán lái', note: 'nhấn nguồn gốc'),
        Variant(zh: '我來自越南', en: "I'm from Vietnam", py: 'wǒ lái zì yuè nán', note: 'phổ biến'),
      ]),
      Equip(zh: '認識你很高興', en: 'Nice to meet you', py: 'rèn shi nǐ hěn gāo xìng', ipa: '/naɪs/', vi: 'Rất vui được gặp bạn', variants: [
        Variant(zh: '很高興認識你', en: 'Glad to meet you', py: 'hěn gāo xìng rèn shi nǐ', note: 'đảo trật tự'),
      ]),
      Equip(zh: '你叫什麼名字', en: "What's your name?", py: 'nǐ jiào shén me míng zì', ipa: '/wɑts/', vi: 'Bạn tên gì?', variants: [
        Variant(zh: '怎麼稱呼', en: 'How should I address you?', py: 'zěn me chēng hū', note: 'rất lịch sự'),
      ]),
      Equip(zh: '你是哪裡人', en: 'Where are you from?', py: 'nǐ shì nǎ lǐ rén', ipa: '/wɛr/', vi: 'Bạn là người nước nào?', variants: [
        Variant(zh: '你從哪裡來', en: 'Where do you come from?', py: 'nǐ cóng nǎ lǐ lái', note: 'cùng nghĩa'),
      ]),
      Equip(zh: '謝謝', en: 'Thank you', py: 'xiè xie', ipa: '/θæŋk ju/', vi: 'Cảm ơn', variants: [
        Variant(zh: '感謝', en: 'Thanks a lot', py: 'gǎn xiè', note: 'trang trọng'),
        Variant(zh: '多謝', en: 'Many thanks', py: 'duō xiè', note: 'đời thường'),
      ]),
      Equip(zh: '再見', en: 'Goodbye', py: 'zài jiàn', ipa: '/ɡʊdˈbaɪ/', vi: 'Tạm biệt', variants: [
        Variant(zh: '掰掰', en: 'Bye bye', py: 'bāi bāi', note: 'hay dùng nhất'),
        Variant(zh: '下次見', en: 'See you', py: 'xià cì jiàn', note: 'hẹn gặp lại'),
      ]),
    ],
    turns: [
      Turn(npcLines: [
        NpcLine(zh: '你好！你叫什麼名字？', en: 'Hello! What is your name?', vi: 'Xin chào! Bạn tên gì?'),
        NpcLine(zh: '嗨～怎麼稱呼你？', en: 'Hi~ how should I call you?', vi: 'Chào~ gọi bạn thế nào?'),
        NpcLine(zh: '你好，請問你叫什麼？', en: 'Hi, may I ask your name?', vi: 'Chào, cho hỏi bạn tên gì?'),
      ], options: ['你好，我叫阿海', '多少錢？', '再見'],
        optionsEn: ["Hello, I'm Hai", 'How much?', 'Goodbye'], hintVi: 'Chào lại và giới thiệu tên'),
      Turn(npcLines: [
        NpcLine(zh: '你是哪裡人？', en: 'Where are you from?', vi: 'Bạn là người nước nào?'),
        NpcLine(zh: '你從哪個國家來的？', en: 'Which country are you from?', vi: 'Bạn đến từ nước nào?'),
        NpcLine(zh: '你不是台灣人吼？', en: "You're not Taiwanese, right?", vi: 'Bạn không phải người Đài đúng không?'),
      ], options: ['我是越南人', '我餓了', '我不知道'],
        optionsEn: ['I am Vietnamese', 'I am hungry', "I don't know"], hintVi: 'Nói bạn đến từ Việt Nam'),
      Turn(npcLines: [
        NpcLine(zh: '歡迎來台灣！', en: 'Welcome to Taiwan!', vi: 'Chào mừng đến Đài Loan!'),
        NpcLine(zh: '台灣很好玩喔，歡迎！', en: 'Taiwan is fun, welcome!', vi: 'Đài Loan vui lắm, chào mừng nha!'),
      ], options: ['認識你很高興', '太貴了', '我要走了'],
        optionsEn: ['Nice to meet you', 'Too expensive', 'I am leaving'], hintVi: 'Đáp lịch sự: rất vui được gặp'),
    ],
    natives: [
      Native(zh: '吃飽沒？', en: 'Have you eaten?', py: 'chī bǎo méi', vi: 'Ăn cơm chưa? (cách CHÀO HỎI, không phải mời ăn — cứ nói "吃飽了")'),
      Native(zh: '你中文很好耶！', en: 'Your Chinese is good!', py: 'nǐ zhōng wén hěn hǎo yē', vi: 'Tiếng Trung bạn giỏi ghê! (khen xã giao, cứ cảm ơn)'),
      Native(zh: '加油！', en: 'Keep going!', py: 'jiā yóu', vi: 'Cố lên! (động viên, nghe rất nhiều)'),
    ],
    tipVi: 'Câu "吃飽沒?" (ăn cơm chưa) thực ra là cách CHÀO HỎI, không phải mời ăn thật — cứ trả lời "吃飽了" (ăn rồi). Người Đài rất kiên nhẫn với người nước ngoài, đừng sợ nói sai.',
    tipEn: '"Have you eaten?" is actually a GREETING, not a real invitation — just say yes. Taiwanese are patient with foreigners, don\'t fear mistakes.',
    badgeVi: 'Đã biết chào hỏi', badgeEn: 'Greeting Master'),

  // ───── NGÀY 2: Số đếm & giá tiền ─────
  Day(day: 2, emoji: '🔢',
    titleVi: 'Số đếm & hỏi giá', titleEn: 'Numbers & Prices',
    sceneVi: 'Bạn vào cửa hàng tiện lợi mua chai nước. Cầm lên quầy, nhân viên nói một con số. Bạn cần hiểu họ nói bao nhiêu tiền để trả đúng...',
    sceneEn: 'You enter a convenience store for a bottle of water. At the counter, the clerk says a number. You need to understand the price to pay correctly...',
    equips: [
      Equip(zh: '多少錢', en: 'How much?', py: 'duō shǎo qián', ipa: '/haʊ mʌtʃ/', vi: 'Bao nhiêu tiền?', variants: [
        Variant(zh: '這個怎麼賣', en: 'How is this sold?', py: 'zhè ge zěn me mài', note: 'cách nói chợ búa'),
        Variant(zh: '多少', en: 'How much (short)', py: 'duō shǎo', note: 'nói tắt'),
      ]),
      Equip(zh: '一', en: 'One', py: 'yī', ipa: '/wʌn/', vi: 'Một'),
      Equip(zh: '十', en: 'Ten', py: 'shí', ipa: '/tɛn/', vi: 'Mười'),
      Equip(zh: '一百', en: 'One hundred', py: 'yì bǎi', ipa: '/ˈhʌndrəd/', vi: 'Một trăm'),
      Equip(zh: '太貴了', en: 'Too expensive', py: 'tài guì le', ipa: '/tu ɪkˈspɛnsɪv/', vi: 'Đắt quá', variants: [
        Variant(zh: '有點貴', en: 'A bit pricey', py: 'yǒu diǎn guì', note: 'nhẹ nhàng hơn'),
      ]),
      Equip(zh: '便宜一點', en: 'Cheaper please', py: 'pián yí yì diǎn', ipa: '/ˈtʃipər/', vi: 'Rẻ hơn chút đi', variants: [
        Variant(zh: '可以算便宜一點嗎', en: 'Can you make it cheaper?', py: 'kě yǐ suàn pián yí yì diǎn ma', note: 'lịch sự'),
      ]),
      Equip(zh: '我要這個', en: 'I want this', py: 'wǒ yào zhè ge', ipa: '/aɪ wɑnt/', vi: 'Tôi muốn cái này'),
      Equip(zh: '可以刷卡嗎', en: 'Can I pay by card?', py: 'kě yǐ shuā kǎ ma', ipa: '/kɑrd/', vi: 'Quẹt thẻ được không?', variants: [
        Variant(zh: '能用信用卡嗎', en: 'Credit card OK?', py: 'néng yòng xìn yòng kǎ ma', note: 'rõ ràng hơn'),
      ]),
    ],
    turns: [
      Turn(npcLines: [
        NpcLine(zh: '一共三十五塊', en: 'Thirty-five total', vi: 'Tổng cộng 35 đồng'),
        NpcLine(zh: '這個三十五元', en: 'This is 35 dollars', vi: 'Cái này 35 đồng'),
      ], options: ['好，我要這個', '我不要', '太遠了'],
        optionsEn: ['Okay, I want this', "I don't want it", 'Too far'], hintVi: 'Đồng ý mua'),
      Turn(npcLines: [
        NpcLine(zh: '要袋子嗎？', en: 'Need a bag?', vi: 'Cần túi không?'),
        NpcLine(zh: '需要塑膠袋嗎？', en: 'Need a plastic bag?', vi: 'Cần túi nilon không?'),
      ], options: ['不用，謝謝', '我餓了', '再見'],
        optionsEn: ['No need, thanks', 'I am hungry', 'Goodbye'], hintVi: 'Từ chối lịch sự (túi mất phí)'),
      Turn(npcLines: [
        NpcLine(zh: '可以刷卡嗎？欸不行喔', en: 'Card? No, cash only', vi: 'Quẹt thẻ? À không được nha'),
        NpcLine(zh: '我們只收現金', en: 'We only take cash', vi: 'Bên mình chỉ nhận tiền mặt'),
      ], options: ['好，我付現金', '太貴了', '我走了'],
        optionsEn: ['Okay, I pay cash', 'Too expensive', 'I leave'], hintVi: 'Đồng ý trả tiền mặt'),
    ],
    natives: [
      Native(zh: '塊', en: 'bucks (dollars)', py: 'kuài', vi: 'Đồng (cách nói tắt của 元, người Đài hay dùng "塊" hơn)'),
      Native(zh: '銅板', en: 'coins', py: 'tóng bǎn', vi: 'Tiền xu'),
      Native(zh: '發票要嗎？', en: 'Want a receipt?', py: 'fā piào yào ma', vi: 'Lấy hóa đơn không? (hóa đơn ở Đài có thể trúng xổ số!)'),
    ],
    tipVi: 'Người Đài nói giá hay dùng "塊" (kuài) thay vì "元" (yuán) — cùng nghĩa "đồng". Hóa đơn 發票 ở Đài Loan có mã số dự xổ số 2 tháng/lần, đừng vứt! Túi nilon ở cửa hàng tính phí 1-2 đồng.',
    tipEn: 'Taiwanese say "kuài" instead of "yuán" for money. Receipts (發票) have lottery numbers — don\'t throw them away! Plastic bags cost extra.',
    badgeVi: 'Đã biết mua sắm', badgeEn: 'Shopping Pro'),

  // ───── NGÀY 3: Gọi món ăn ─────
  Day(day: 3, emoji: '🍜',
    titleVi: 'Gọi món ở quán ăn', titleEn: 'Ordering Food',
    sceneVi: 'Bụng đói cồn cào, bạn bước vào quán mì. Chủ quán cầm bút chờ bạn gọi món. Mùi thơm bốc lên, nhưng bạn chưa biết gọi thế nào...',
    sceneEn: 'Starving, you walk into a noodle shop. The owner waits with a pen. The aroma rises, but you don\'t know how to order...',
    equips: [
      Equip(zh: '我要一碗麵', en: 'One bowl of noodles', py: 'wǒ yào yì wǎn miàn', ipa: '/noʊdəlz/', vi: 'Cho tôi một tô mì', variants: [
        Variant(zh: '來一碗麵', en: 'A bowl of noodles', py: 'lái yì wǎn miàn', note: 'gọn, tự nhiên'),
      ]),
      Equip(zh: '不要辣', en: 'Not spicy', py: 'bú yào là', ipa: '/nɑt ˈspaɪsi/', vi: 'Không cay', variants: [
        Variant(zh: '小辣', en: 'Mild spicy', py: 'xiǎo là', note: 'cay nhẹ'),
        Variant(zh: '不要香菜', en: 'No cilantro', py: 'bú yào xiāng cài', note: 'không rau mùi'),
      ]),
      Equip(zh: '好吃', en: 'Delicious', py: 'hǎo chī', ipa: '/dɪˈlɪʃəs/', vi: 'Ngon', variants: [
        Variant(zh: '很好吃', en: 'Very delicious', py: 'hěn hǎo chī', note: 'nhấn'),
      ]),
      Equip(zh: '內用', en: 'Dine in', py: 'nèi yòng', ipa: '/daɪn ɪn/', vi: 'Ăn tại quán'),
      Equip(zh: '外帶', en: 'Take out', py: 'wài dài', ipa: '/teɪk aʊt/', vi: 'Mang đi'),
      Equip(zh: '買單', en: 'Check please', py: 'mǎi dān', ipa: '/tʃɛk/', vi: 'Tính tiền', variants: [
        Variant(zh: '結帳', en: 'Bill please', py: 'jié zhàng', note: 'cũng rất hay dùng'),
      ]),
      Equip(zh: '我要一杯水', en: 'A glass of water', py: 'wǒ yào yì bēi shuǐ', ipa: '/ˈwɔtər/', vi: 'Cho tôi một ly nước'),
    ],
    turns: [
      Turn(npcLines: [
        NpcLine(zh: '要點什麼？', en: 'What would you like?', vi: 'Gọi gì ạ?'),
        NpcLine(zh: '想吃什麼？', en: 'What do you want to eat?', vi: 'Muốn ăn gì?'),
        NpcLine(zh: '來點什麼？', en: 'What can I get you?', vi: 'Dùng gì nào?'),
      ], options: ['我要一碗麵', '多少錢', '再見'],
        optionsEn: ['One bowl of noodles', 'How much', 'Bye'], hintVi: 'Gọi một tô mì'),
      Turn(npcLines: [
        NpcLine(zh: '要辣嗎？', en: 'Spicy?', vi: 'Có cay không?'),
        NpcLine(zh: '辣度可以嗎？', en: 'Spice level OK?', vi: 'Độ cay được chứ?'),
      ], options: ['不要辣，謝謝', '我是越南人', '太貴了'],
        optionsEn: ['Not spicy, thanks', 'I am Vietnamese', 'Too expensive'], hintVi: 'Nói không cay'),
      Turn(npcLines: [
        NpcLine(zh: '內用還是外帶？', en: 'Dine in or take out?', vi: 'Ăn ở đây hay mang đi?'),
        NpcLine(zh: '這裡吃還是帶走？', en: 'Eat here or take away?', vi: 'Ăn đây hay đem về?'),
      ], options: ['內用', '我不知道', '不好吃'],
        optionsEn: ['Dine in', "I don't know", 'Not tasty'], hintVi: 'Chọn ăn tại quán'),
    ],
    natives: [
      Native(zh: '老闆', en: 'Boss (owner)', py: 'lǎo bǎn', vi: 'Ông/bà chủ (gọi chủ quán là 老闆, kể cả quán nhỏ)'),
      Native(zh: '加麵', en: 'Extra noodles', py: 'jiā miàn', vi: 'Thêm mì'),
      Native(zh: '免費續湯', en: 'Free soup refill', py: 'miǎn fèi xù tāng', vi: 'Thêm canh miễn phí (nhiều quán Đài có)'),
    ],
    tipVi: 'Gọi chủ quán là "老闆" (lǎo bǎn) dù quán to hay nhỏ — vừa lịch sự vừa thân thiện. Nhiều quán mì cho thêm canh/nước dùng miễn phí, cứ hỏi "可以續湯嗎?". Người Đài ít ăn cay, "辣" với họ có thể nhẹ hơn bạn nghĩ.',
    tipEn: 'Call the owner "lǎo bǎn" regardless of shop size. Many noodle shops offer free soup refills. Taiwanese "spicy" may be milder than you expect.',
    badgeVi: 'Đã biết gọi món', badgeEn: 'Food Orderer'),

  // ───── NGÀY 4: Đi MRT / xe buýt ─────
  Day(day: 4, emoji: '🚇',
    titleVi: 'Đi lại bằng MRT', titleEn: 'Getting Around by MRT',
    sceneVi: 'Bạn cần đến trung tâm thành phố nhưng không biết đi tàu điện ngầm thế nào. Trước cửa ga MRT đông người, bạn dừng lại hỏi một nhân viên...',
    sceneEn: 'You need to get downtown but don\'t know the MRT. The station is crowded; you stop to ask a staff member...',
    equips: [
      Equip(zh: '捷運站在哪裡', en: 'Where is the MRT?', py: 'jié yùn zhàn zài nǎ lǐ', ipa: '/wɛr/', vi: 'Ga MRT ở đâu?', variants: [
        Variant(zh: '怎麼去捷運站', en: 'How to get to MRT?', py: 'zěn me qù jié yùn zhàn', note: 'hỏi đường'),
      ]),
      Equip(zh: '我要去台北車站', en: 'I go to Taipei Station', py: 'wǒ yào qù tái běi chē zhàn', ipa: '/aɪ ɡoʊ/', vi: 'Tôi muốn đi ga Đài Bắc'),
      Equip(zh: '悠遊卡', en: 'EasyCard', py: 'yōu yóu kǎ', ipa: '/ˈizikɑrd/', vi: 'Thẻ EasyCard', variants: [
        Variant(zh: '可以加值嗎', en: 'Can I top up?', py: 'kě yǐ jiā zhí ma', note: 'nạp thẻ'),
      ]),
      Equip(zh: '多遠', en: 'How far?', py: 'duō yuǎn', ipa: '/haʊ fɑr/', vi: 'Bao xa?'),
      Equip(zh: '要多久', en: 'How long?', py: 'yào duō jiǔ', ipa: '/haʊ lɔŋ/', vi: 'Mất bao lâu?'),
      Equip(zh: '在哪裡下車', en: 'Where to get off?', py: 'zài nǎ lǐ xià chē', ipa: '/ɡɛt ɔf/', vi: 'Xuống ở đâu?'),
      Equip(zh: '謝謝你的幫忙', en: 'Thanks for your help', py: 'xiè xie nǐ de bāng máng', ipa: '/hɛlp/', vi: 'Cảm ơn bạn đã giúp'),
    ],
    turns: [
      Turn(npcLines: [
        NpcLine(zh: '你要去哪裡？', en: 'Where do you want to go?', vi: 'Bạn muốn đi đâu?'),
        NpcLine(zh: '請問到哪一站？', en: 'Which station?', vi: 'Cho hỏi đến ga nào?'),
      ], options: ['我要去台北車站', '多少錢', '我餓了'],
        optionsEn: ['I go to Taipei Station', 'How much', 'I am hungry'], hintVi: 'Nói điểm đến'),
      Turn(npcLines: [
        NpcLine(zh: '有悠遊卡嗎？', en: 'Do you have EasyCard?', vi: 'Có thẻ EasyCard không?'),
        NpcLine(zh: '你刷卡還是買票？', en: 'Card or ticket?', vi: 'Quẹt thẻ hay mua vé?'),
      ], options: ['有，我有悠遊卡', '太遠了', '不好吃'],
        optionsEn: ['Yes, I have EasyCard', 'Too far', 'Not tasty'], hintVi: 'Có thẻ EasyCard'),
      Turn(npcLines: [
        NpcLine(zh: '坐到第三站下車', en: 'Get off at the 3rd stop', vi: 'Đi đến ga thứ 3 thì xuống'),
        NpcLine(zh: '三站就到了', en: 'Three stops away', vi: 'Ba ga là tới'),
      ], options: ['好，謝謝你的幫忙', '我不要', '再見'],
        optionsEn: ['Okay, thanks for help', "I don't want", 'Bye'], hintVi: 'Cảm ơn vì đã giúp'),
    ],
    natives: [
      Native(zh: '博愛座', en: 'Priority seat', py: 'bó ài zuò', vi: 'Ghế ưu tiên (người Đài rất nghiêm việc nhường ghế này, đừng ngồi nếu khỏe mạnh)'),
      Native(zh: '小心月台間隙', en: 'Mind the gap', py: 'xiǎo xīn yuè tái jiàn xì', vi: 'Cẩn thận khe sân ga (thông báo trên tàu)'),
      Native(zh: '不能吃東西', en: 'No eating', py: 'bù néng chī dōng xī', vi: 'Cấm ăn uống (trên MRT Đài cấm ăn uống, phạt nặng!)'),
    ],
    tipVi: 'Trên MRT Đài Loan CẤM ăn uống (kể cả kẹo, nước) — phạt tới 7,500 NTD! Ghế "博愛座" (ưu tiên) gần như bất khả xâm phạm, đừng ngồi nếu bạn khỏe. Mua thẻ 悠遊卡 ở cửa hàng tiện lợi, dùng được cả MRT, xe buýt, mua đồ.',
    tipEn: 'NO eating/drinking on Taiwan MRT — fines up to 7,500 NTD! Priority seats are sacred. Buy an EasyCard at convenience stores; works for MRT, buses, and shopping.',
    badgeVi: 'Đã biết đi MRT', badgeEn: 'MRT Navigator'),

  // ───── NGÀY 5: Hỏi đường ─────
  Day(day: 5, emoji: '🧭',
    titleVi: 'Hỏi đường khi lạc', titleEn: 'Asking Directions',
    sceneVi: 'Bạn ra khỏi ga nhưng không biết đi hướng nào. Điện thoại hết pin. Một người đi đường đang tới gần, bạn quyết định hỏi...',
    sceneEn: 'You exit the station but don\'t know which way. Your phone is dead. A passerby approaches; you decide to ask...',
    equips: [
      Equip(zh: '怎麼走', en: 'How to get there?', py: 'zěn me zǒu', ipa: '/haʊ/', vi: 'Đi thế nào?', variants: [
        Variant(zh: '怎麼去', en: 'How to go?', py: 'zěn me qù', note: 'cùng nghĩa'),
      ]),
      Equip(zh: '左轉', en: 'Turn left', py: 'zuǒ zhuǎn', ipa: '/lɛft/', vi: 'Rẽ trái'),
      Equip(zh: '右轉', en: 'Turn right', py: 'yòu zhuǎn', ipa: '/raɪt/', vi: 'Rẽ phải'),
      Equip(zh: '直走', en: 'Go straight', py: 'zhí zǒu', ipa: '/streɪt/', vi: 'Đi thẳng'),
      Equip(zh: '在哪裡', en: 'Where?', py: 'zài nǎ lǐ', ipa: '/wɛr/', vi: 'Ở đâu?'),
      Equip(zh: '附近有便利商店嗎', en: 'Any store nearby?', py: 'fù jìn yǒu biàn lì shāng diàn ma', ipa: '/nɪrˈbaɪ/', vi: 'Gần đây có cửa hàng tiện lợi không?'),
      Equip(zh: '我迷路了', en: "I'm lost", py: 'wǒ mí lù le', ipa: '/lɔst/', vi: 'Tôi bị lạc', variants: [
        Variant(zh: '我找不到路', en: "I can't find the way", py: 'wǒ zhǎo bú dào lù', note: 'cụ thể hơn'),
      ]),
    ],
    turns: [
      Turn(npcLines: [
        NpcLine(zh: '你要找什麼？', en: 'What are you looking for?', vi: 'Bạn tìm gì?'),
        NpcLine(zh: '需要幫忙嗎？', en: 'Need help?', vi: 'Cần giúp không?'),
      ], options: ['我迷路了，便利商店在哪裡？', '多少錢', '再見'],
        optionsEn: ['I am lost, where is a store?', 'How much', 'Bye'], hintVi: 'Nói bị lạc, hỏi cửa hàng'),
      Turn(npcLines: [
        NpcLine(zh: '前面直走右轉', en: 'Straight then turn right', vi: 'Đi thẳng rồi rẽ phải'),
        NpcLine(zh: '直走到路口右轉', en: 'Straight to the corner, turn right', vi: 'Đi thẳng đến ngã tư rẽ phải'),
      ], options: ['好的，謝謝', '太貴了', '我餓了'],
        optionsEn: ['Okay, thanks', 'Too expensive', 'I am hungry'], hintVi: 'Hiểu và cảm ơn'),
    ],
    natives: [
      Native(zh: '巷子', en: 'alley/lane', py: 'xiàng zi', vi: 'Ngõ/hẻm (địa chỉ Đài hay có 巷, 弄 — ngõ nhỏ)'),
      Native(zh: '紅綠燈', en: 'traffic light', py: 'hóng lǜ dēng', vi: 'Đèn giao thông (mốc chỉ đường quen thuộc)'),
      Native(zh: '對面', en: 'opposite side', py: 'duì miàn', vi: 'Phía đối diện'),
    ],
    tipVi: 'Địa chỉ Đài Loan có cấu trúc 號 (số nhà) → 巷 (ngõ) → 弄 (hẻm nhỏ) → 路/街 (đường). Người Đài rất nhiệt tình chỉ đường, có khi dẫn đi tận nơi. Nếu lạc, vào cửa hàng tiện lợi (7-11, FamilyMart) hỏi — họ luôn giúp.',
    tipEn: 'Taiwan addresses go: number → 巷 (lane) → 弄 (alley) → road. Taiwanese are very helpful with directions. If lost, ask at any convenience store.',
    badgeVi: 'Đã biết hỏi đường', badgeEn: 'Direction Finder'),

  // ───── NGÀY 6: Thuê nhà ─────
  Day(day: 6, emoji: '🏠',
    titleVi: 'Tìm & thuê phòng trọ', titleEn: 'Renting a Room',
    sceneVi: 'Bạn cần tìm chỗ ở. Thấy tờ giấy "出租" (cho thuê) dán trước một tòa nhà, bạn gọi số điện thoại. Chủ nhà bắt máy...',
    sceneEn: 'You need a place to live. You see a "for rent" sign and call the number. The landlord picks up...',
    equips: [
      Equip(zh: '我想租房子', en: 'I want to rent', py: 'wǒ xiǎng zū fáng zi', ipa: '/rɛnt/', vi: 'Tôi muốn thuê nhà', variants: [
        Variant(zh: '還有房間嗎', en: 'Any rooms left?', py: 'hái yǒu fáng jiān ma', note: 'hỏi còn phòng'),
      ]),
      Equip(zh: '房租多少', en: 'How much rent?', py: 'fáng zū duō shǎo', ipa: '/rɛnt/', vi: 'Tiền thuê bao nhiêu?'),
      Equip(zh: '押金', en: 'Deposit', py: 'yā jīn', ipa: '/dɪˈpɑzɪt/', vi: 'Tiền đặt cọc'),
      Equip(zh: '水電費', en: 'Utility bills', py: 'shuǐ diàn fèi', ipa: '/juˈtɪləti/', vi: 'Tiền điện nước', variants: [
        Variant(zh: '含水電嗎', en: 'Utilities included?', py: 'hán shuǐ diàn ma', note: 'hỏi đã gồm chưa'),
      ]),
      Equip(zh: '可以看房嗎', en: 'Can I view it?', py: 'kě yǐ kàn fáng ma', ipa: '/vju/', vi: 'Xem phòng được không?'),
      Equip(zh: '什麼時候可以入住', en: 'When can I move in?', py: 'shén me shí hòu kě yǐ rù zhù', ipa: '/muv ɪn/', vi: 'Khi nào dọn vào được?'),
      Equip(zh: '有網路嗎', en: 'Is there wifi?', py: 'yǒu wǎng lù ma', ipa: '/ˈwaɪfaɪ/', vi: 'Có mạng không?'),
    ],
    turns: [
      Turn(npcLines: [
        NpcLine(zh: '你要找幾人房？', en: 'Room for how many?', vi: 'Phòng cho mấy người?'),
        NpcLine(zh: '一個人住嗎？', en: 'Living alone?', vi: 'Ở một mình à?'),
      ], options: ['一個人，房租多少？', '我餓了', '太遠了'],
        optionsEn: ['One person, how much rent?', 'I am hungry', 'Too far'], hintVi: 'Một người, hỏi giá thuê'),
      Turn(npcLines: [
        NpcLine(zh: '一個月八千，押金兩個月', en: '8000/month, 2-month deposit', vi: '8000/tháng, cọc 2 tháng'),
        NpcLine(zh: '租金八千，要押兩個月', en: 'Rent 8000, deposit 2 months', vi: 'Thuê 8000, cọc 2 tháng'),
      ], options: ['含水電嗎？', '不好吃', '再見'],
        optionsEn: ['Utilities included?', 'Not tasty', 'Bye'], hintVi: 'Hỏi đã gồm điện nước chưa'),
      Turn(npcLines: [
        NpcLine(zh: '水電另外算', en: 'Utilities separate', vi: 'Điện nước tính riêng'),
      ], options: ['好，可以看房嗎？', '太貴了我走了', '我不知道'],
        optionsEn: ['Okay, can I view it?', "Too expensive I'm leaving", "I don't know"], hintVi: 'Xin xem phòng'),
    ],
    natives: [
      Native(zh: '套房', en: 'studio (en-suite)', py: 'tào fáng', vi: 'Phòng khép kín (có WC riêng)'),
      Native(zh: '雅房', en: 'room (shared bath)', py: 'yǎ fáng', vi: 'Phòng dùng chung WC (rẻ hơn 套房)'),
      Native(zh: '二房東', en: 'sublease landlord', py: 'èr fáng dōng', vi: 'Chủ cho thuê lại (cẩn thận, nên gặp chủ thật)'),
    ],
    tipVi: 'Phân biệt 套房 (phòng khép kín, có WC riêng) và 雅房 (chung WC, rẻ hơn). Cọc thường 1-2 tháng. CẨN THẬN với "二房東" (chủ cho thuê lại) — nên xem hợp đồng kỹ, chụp ảnh phòng lúc nhận để khỏi mất cọc oan. Đòi hóa đơn điện nước thật.',
    tipEn: 'Know 套房 (en-suite) vs 雅房 (shared bath, cheaper). Deposit usually 1-2 months. Beware subleasing landlords — check contracts and photograph the room when moving in.',
    badgeVi: 'Đã biết thuê nhà', badgeEn: 'Home Hunter'),

  // ───── NGÀY 7: Khám bệnh ─────
  Day(day: 7, emoji: '🏥',
    titleVi: 'Đi khám ở bệnh viện', titleEn: 'Visit the Hospital',
    sceneVi: 'Bạn sốt 3 ngày liền, người mệt rũ. Hôm nay bắt buộc phải đến phòng khám. Cửa kính tự mở, y tá nhìn bạn và hỏi điều gì đó...',
    sceneEn: 'Fever for 3 days, exhausted. You must visit a clinic. The door opens, a nurse looks at you and asks something...',
    equips: [
      Equip(zh: '我生病了', en: 'I am sick', py: 'wǒ shēng bìng le', ipa: '/sɪk/', vi: 'Tôi bị bệnh', variants: [
        Variant(zh: '我不舒服', en: "I don't feel well", py: 'wǒ bù shū fú', note: 'khó chịu chung'),
      ]),
      Equip(zh: '我發燒', en: 'I have a fever', py: 'wǒ fā shāo', ipa: '/ˈfivər/', vi: 'Tôi bị sốt'),
      Equip(zh: '我頭痛', en: 'I have a headache', py: 'wǒ tóu tòng', ipa: '/ˈhɛdeɪk/', vi: 'Tôi đau đầu', variants: [
        Variant(zh: '我肚子痛', en: 'Stomachache', py: 'wǒ dù zi tòng', note: 'đau bụng'),
        Variant(zh: '我喉嚨痛', en: 'Sore throat', py: 'wǒ hóu lóng tòng', note: 'đau họng'),
      ]),
      Equip(zh: '健保卡', en: 'Health card', py: 'jiàn bǎo kǎ', ipa: '/hɛlθ/', vi: 'Thẻ bảo hiểm y tế'),
      Equip(zh: '我要看醫生', en: 'I need a doctor', py: 'wǒ yào kàn yī shēng', ipa: '/ˈdɑktər/', vi: 'Tôi cần gặp bác sĩ'),
      Equip(zh: '藥局在哪', en: 'Where is pharmacy?', py: 'yào jú zài nǎ', ipa: '/ˈfɑrməsi/', vi: 'Nhà thuốc ở đâu?'),
      Equip(zh: '謝謝醫生', en: 'Thank you doctor', py: 'xiè xie yī shēng', ipa: '/ˈdɑktər/', vi: 'Cảm ơn bác sĩ'),
    ],
    turns: [
      Turn(npcLines: [
        NpcLine(zh: '你好，哪裡不舒服？', en: "Hello, what's wrong?", vi: 'Xin chào, chỗ nào khó chịu?'),
        NpcLine(zh: '怎麼了？', en: "What's the matter?", vi: 'Sao vậy?'),
        NpcLine(zh: '不舒服喔？哪裡？', en: 'Not well? Where?', vi: 'Khó chịu à? Chỗ nào?'),
      ], options: ['我生病了，我發燒', '多少錢', '我要租房子'],
        optionsEn: ['I am sick, I have a fever', 'How much', 'I want to rent'], hintVi: 'Nói bị bệnh và sốt'),
      Turn(npcLines: [
        NpcLine(zh: '有帶健保卡嗎？', en: 'Have your health card?', vi: 'Có mang thẻ y tế không?'),
        NpcLine(zh: '健保卡給我', en: 'Health card please', vi: 'Cho mình thẻ y tế'),
      ], options: ['有，這是我的健保卡', '我不喜歡', '太遠了'],
        optionsEn: ['Yes, here is my card', "I don't like it", 'Too far'], hintVi: 'Có — đưa thẻ 健保卡 ra'),
      Turn(npcLines: [
        NpcLine(zh: '請稍等，醫生馬上來', en: 'Please wait, doctor coming', vi: 'Đợi chút, bác sĩ đến ngay'),
        NpcLine(zh: '坐著等一下喔', en: 'Have a seat and wait', vi: 'Ngồi đợi chút nha'),
      ], options: ['好的，謝謝', '不要', '我走了'],
        optionsEn: ['Okay, thank you', 'No', 'I leave'], hintVi: 'Đồng ý và cảm ơn'),
    ],
    natives: [
      Native(zh: '掛號', en: 'register (check-in)', py: 'guà hào', vi: 'Đăng ký khám (việc đầu tiên khi đến bệnh viện)'),
      Native(zh: '診所', en: 'clinic', py: 'zhěn suǒ', vi: 'Phòng khám nhỏ (bệnh nhẹ đến đây nhanh & rẻ hơn bệnh viện lớn 醫院)'),
      Native(zh: '領藥', en: 'collect medicine', py: 'lǐng yào', vi: 'Lấy thuốc (sau khi khám)'),
    ],
    tipVi: 'LUÔN mang thẻ 健保卡 — có thẻ chỉ trả ~150-400 NTD, không có phải trả gấp 3-5 lần. Bệnh nhẹ nên đến 診所 (phòng khám) thay vì 醫院 (bệnh viện lớn) — nhanh và rẻ hơn. Đến nơi việc đầu tiên là 掛號 (đăng ký). Chưa có thẻ? Gọi 1955.',
    tipEn: 'ALWAYS bring your health card — pay ~150-400 NTD with it, 3-5x more without. For minor illness go to a 診所 (clinic), not a big hospital. First step is 掛號 (register). No card yet? Call 1955.',
    badgeVi: 'Đã biết đi khám bệnh', badgeEn: 'Hospital Survivor'),
];

// ════════════════════════════════════════════════════════════════
// DANH SÁCH TỔNG — cộng dồn tất cả các tuần/tháng
// Thêm tuần mới: chỉ cần thêm 1 dòng "...tenTuan," vào đây.
// ════════════════════════════════════════════════════════════════
final List<Day> journeyDays = [
  ...week1,
  // ...week2,   ← Tuần 2 (sắp thêm)
  // ...week3,
  // ...week4,
  // ...month2,  ← Tháng 2 (tương lai)
];