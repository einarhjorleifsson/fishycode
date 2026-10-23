# logbook_notes.R — the rules that classify a logbook's free-text note (decision 213, plan 020 §6).
#
# A note is folded (note_fold), then tagged by regular expressions (note_rules): every tag that matches, and a main
# class, the class of its highest-priority tag (note_classes order). note_species names the species a note names, with
# the landings' codes (kvoti.lods_fteg, shared by fs and adb, decision 182). classify_notes() applies them all.
# The rules were built and counted on every note, 2026-10-23: $FISHYDATA/archive/2026-10-logbook-notes/README.md.
# Folding: lower case; þ -> th, æ -> ae, ð -> d, accents off; the sent XML's lost letters (¿) -> "_", which the
# patterns accept where a letter may be lost.

note_fold <- function(x) {
  x <- tolower(x)
  x <- gsub("þ", "th", x, fixed = TRUE); x <- gsub("æ", "ae", x, fixed = TRUE); x <- gsub("ð", "d", x, fixed = TRUE)
  x <- chartr("áéíóúýöäüåøç", "aeiouyoauaoc", x)
  x <- gsub("¿", "_", x, fixed = TRUE)
  x <- gsub("[´`’']", "", x)
  # a unit or "kg" glued to a word ("kgmac", "45kgher", "kgdælt") is split from it
  x <- gsub("(\\d|\\b)(kg|tn)(mac|mak|makr|her|whb|cap|sild|kolm|dael|d_l)", "\\1\\2 \\3", x, perl = TRUE)
  gsub("\\s+", " ", trimws(x))
}

# Classes, in priority order (a note's main class is the first that any of its tags belongs to).
note_classes <- function() c(
  provenance        = "written by a system, not the skipper (afli's monthly summaries)",
  record_status     = "the record itself: void, a test, an error, a correction, the wrong gear",
  transfer          = "catch pumped, given or taken between vessels",
  pair_trawl        = "two vessels towing one trawl, or one vessel acting as the other's door",
  released          = "catch released alive or discarded: outside the recorded catch",
  sample_research   = "an MFRI sample, a survey station, research, tagging, an inspector; a processing test",
  sensitive_bycatch = "mammals, birds and large sharks caught (not stated as released)",
  gear_lost         = "gear or a part of it lost",
  gear_trouble      = "snagged, torn, tangled, broken, machinery failure (afli's remark codes 1-14)",
  twin_trawl        = "two trawls towed by one vessel (afli's remark code 20), or one stated",
  catch             = "no catch, catch disposition (fish farming, bait), catch items, size, species and amounts",
  gear_config       = "codend, grid, rope, jig and line rig, nets, traps, dredges, buoy colours, the gear named",
  effort_time       = "tow time, soak nights, hours",
  place             = "fishing ground, area, tow direction, depth or length in fathoms, distance",
  environment       = "weather, current, bottom",
  admin             = "paper logbook, the app, quota, landing, apologies, stoppages",
  unclear           = "empty, punctuation, a letter or a number alone",
  other             = "no rule matched")

note_rules <- function() {
  L <- "[a-z_]"   # a letter, or one the sent XML lost
  rule <- function(tag, class, pattern) data.frame(tag = tag, class = class, pattern = pattern)
  r <- rbind(
    rule("summary_record", "provenance", "samantekt"),

    rule("void", "record_status", paste0(
      "(^|[^a-z])(o|_)gil(t|d|dur|da|di)\\b|\\btest(\\b|ing)|\\b(bull|rugl|vitleysa|vitleysu|bulli)\\b|",
      "\\bekki (hal|holi|tog|togad|kast|kastad|dregid|veidi|lagt|logd)\\b|\\b(o|_)vart\\b|\\beyd(a|a thessu|i)\\b|\\beytt\\b|",
      "\\btvi(skrad|skrad|faert|tekin|tekid)|\\bsama (tog|hal|kast) (og|tvisvar)|\\bekki gil(t|d)\\b|accidental|prufusend|plat ?tog|\\bekki hol\\b|\\bekkert hol\\b|\\bekkert tog\\b|\\bekki kastad|\\b(fo|_)r ekki fram|mistogst")),
    rule("error", "record_status", paste0(
      "\\b(villa|villu|villur|mistok|mist_k|mistokum|vitlaus\\w*|vitleisa|rangt|ramgt|ranga|rangur|rong|r_ng)\\b|\\bgle(y|i)md(ist|i|um)\\b|\\bfeil|prentvill|innslattavill|of mikid skr|oftalin|ofskrad|datt (u|ut|ur)\\b|dottid ut|\\bekki r(e|_)tt\\b|t(o|_)lvumist")),
    rule("correction", "record_status", paste0(
      "\\b(a|_) ad vera\\b|\\batti ad vera\\b|\\bleidrett\\w*|\\bbreytt\\w*\\b|\\bbreyti\\b|\\brett (er|ad|tala)\\b|",
      "\\bskrad (a|i) (rangt|vitlaust)|\\bskradi (a|i) vitlaus|\\bekki haegt ad breyta|\\bskrad \\w+ \\d+\\.? ?en (eru|er|var)")),
    rule("species_correction", "record_status", "\\b(annar fiskur|annarfiskur|bland|mix|(o|_)skilgr\\w*) er\\b|\\ber ekki \\w+ (heldur|er)\\b"),
    rule("depth_unit", "record_status", "d(y|_|&apos;y)pi.{0,20}(fodm|f_dm|metr|fm\\b)|\\bi fodmum|\\bi metrum"),
    rule("gear_correction", "record_status", paste0(
      "(a|_) ad vera (\\w+ )?(not|troll|varpa|lina|linu|net|faeri|plogur|dragnot|gildr)\\w*|",
      "\\b(erum|vorum|var|er) (a|med|_) (not|troll|linu|net|faer\\w*|dragnot|plog\\w*|handfaer\\w*)\\b|",
      "\\bekki (humar|raekju|fisk)?(troll|varpa|vorpu)\\b|botnvarpa ekki|\\bekki (net|lina|not|faeri|botnvarpa|bacalao)\\b|\\bveitt (med|i) (n|_)(o|_)t|\\bveidarfaeri var\\b|\\bveitt i \\w*not")),

    rule("transfer", "transfer", paste0(
      "d(ae|_|a)l(t|d|di|dum|um|ir|da|dur|t\\w*)\\b|\\bpump\\w*|\\bgefins\\b|\\bg(a|_)fum\\b|\\bgefid\\b|\\bgefin\\b|",
      "\\bfeng(um|u|ust)? (gefins|hja|fra)\\b|\\bafl(i|inn|inum|anum|a) (i|fra|ur|til|a) (?!poka|lagi|sjo|bord|lest|dag|dekk|kor|kass|kar\\b|land|gaer|morgun|thessu|thvi|hal|hol)", L, "{3,}|",
      "\\btok(um)? aflann\\b|\\bvid t(o|_)kum (aflann|pokann)\\b|\\bmidl(a|ad|adi|um)\\b|\\btekid vid afla|",
      "\\b(d|_)?(ae|a|k|_)?(ae)?l{1,2}(t|dum|um|di|m|f|lt|du)\\b(?<!\\b(al|alt|all|allt|alum|aldu|aelt|alm|ali|alf)\\b)|\\bbaelt\\b|\\bdael\\b|\\bdaa?el|\\bdae?tt?\\b|\\baelt\\b|\\bdfengum|",
      "\\bsett(ur|um|i)?\\b( \\w+){0,2} (i|a|yfir|um bord|_)\\b(?! ?(sjokvi|kvi|drull|eldi|gang|lest|kar\\b|frost|braedsl|poka|sjo|nv|sv|na|sa|land|papp|bok|kostun|vitlaus|tog|sjoinn))|\\bset (i|um bord)\\b|\\bsetti\\b|\\btek(id|in|inn|inn|um|ur)\\b( \\w+){0,3} (fra|hja|af|ur)\\b|\\btefinn\\b|",
      "\\bfe(n|in)g(in|inn|id|um|u|ust)\\b( \\w+){0,4} (hja|fra|ur|h_)\\b|\\bgaf (okkur|theim)|\\bgef(um|a)\\b|\\bseldur um bor|\\btekur (aflann|pokann)|\\bfor (um bord )?i \\d{3,4}\\b|",
      "\\d ?(t|tn|tonn\\w*|ton|tomm|kg)\\.? (af \\w+ )?(\\w+ )?(fra|hja|yfir i|yfir|i|ur|til) (?!hol|afla|kg|poka|lest|kar|kass|tur|sjo|land|stk|dag|hverri|kast|tog|thessu|fyrr|sidast|veidiferd|braedsl|sjokvi|eldi|drull|frost|haf)[a-z_]{3,}|",
      "\\bafl(i|inn) (fr(a|_)|i|for i) \\d{3,4}\\b|\\b\\d{4} t(o|_)k afla|^\\+ ?\\w|",
      "\\bf(e|_)kk\\b|\\bf(ae|_)r\\b|\\bfaum\\b|\\bfe(i)?gum\\b|\\bgafdum\\b|\\bgefur\\b|\\bgjof\\b|\\bgefi(n|_|d|nd)\\b|\\bgrfins\\b|\\bafg(ang)?\\b|",
      "^(fr(a|_)|hj(a|_)) [a-z_]{3,}|\\b(i|til|fra|hja) [a-z_]{3,}\\.? (ve|re|gk|ns|nk|ea|su|ak|thh|th|sf|ke|si|of|is|sh)\\b")),

    rule("pair_trawl", "pair_trawl", paste0(
      "tv(i|_)lemb|\\bhler(i|ar|um) (fyrir|med|hja)\\b|\\berum hler(i|ar)\\b|\\bpar(a|ad|i)?troll|\\bparad\\b|\\bi pari\\b|",
      "\\btveggja ?bata ?troll|\\bsamtog|\\btogudum saman|\\bpar troll|\\bpartroll")),

    rule("released", "released", "\\bsle(pp|p|f|ff)(t|ti|tum|tu|a|um|ur|ir|ar)?\\b|\\bse(l)?ppt\\b|ludusleppt|sleppt\\b|\\blifandi\\b|\\bgefid lif|\\bfell(u)? ur neti|afli i sjoinn"),
    rule("discarded", "released", "\\bhenn?t(um|i)?\\b|\\bhenda\\b|\\bfleyg(t|dum|dum)\\b|\\bfyrir bord\\b|\\bkastad (ut|fyrir)|\\bbrottkast|\\bdiscard"),

    rule("processing_test", "sample_research", "fryst(i|i )?prufa|prufa (i|_) frost|vinnsluprufa|prufa fyrir (frystingu|vinnslu)"),
    rule("mfri_sample", "sample_research", paste0(
      "hafr(o|_)?\\W?(prufa|prufu|pr\\b|syni|s_ni|synataka|sild|makril|kolmunn|rannsok)|prufa (til|fyrir|handa|i) hafr|",
      "prufa\\b|prufu\\b|prufan\\b|prufur\\b|prufutak|\\bs(y|_)ni\\b|\\bsynatak|\\bs(y|_)ni tek|\\bteki(d|_|n|nn) s(y|_)ni|(syni|s_ni)\\b|\\baflasyni|\\bhafr(o|i|_)\\b|\\btalning \\d")),
    rule("survey", "sample_research", "rall\\b|ralli\\b|\\bstofnmael|\\bleidangur"),
    rule("research", "sample_research", "rannsok|ransok|tilraun|veidarfaerarann|\\bkonnun|prufutog|leitartog|^l ?eit\\W*$|\\bleit (ad|eftir)\\b|\\baukatog"),
    rule("tagging", "sample_research", "\\bmerk(ing|ingar|ingu|t|tur|tir|ja|jum|tum)\\b"),
    rule("observer", "sample_research", "\\beftirlitsm|\\bveidieftirlit|\\beftirlit\\b|\\beftirlitsmadur"),

    rule("greenland_shark", "sensitive_bycatch", "\\bgrh\\b|(?<!bein)h(a|_)karl|\\bgsk\\b|\\bhakal"),
    rule("basking_shark", "sensitive_bycatch", "beinh(a|_)karl"),
    rule("porbeagle", "sensitive_bycatch", "h(a|_)mer(i|a|u|ur)?\\b"),
    rule("mammal", "sensitive_bycatch", paste0(
      "\\bland(s)?\\.? ?\\d+ ?kg|\\d\\.? ?land\\b|\\bsel(ur|ir|i|a|um|s|inn)?\\b|selur\\b|selir\\b|selsk|\\bkop(ur|ar)\\b|landsel|utsel|hn(i|y|_)s(a|ur|u|um|an)\\b|\\bhval|hrefn|hnufubak|hofrung|grindhv|\\bspendyr|\\bhrae\\b|\\bfostur\\b|\\bvetrung")),
    rule("bird", "sensitive_bycatch", paste0(
      "fugl(?!afj)|\\baed(ur|i|ar)\\b|aedarfug|aedafug|\\bkoll(a|ur|u)\\b|teist|svartfug|skarf|\\bsul(a|ur|u)\\b|\\bfyl(l|ar)\\b|",
      "\\blund(i|ar|a)\\b|\\bmaf(ur|ar)\\b|langvi|himbrim|\\blom(ur|ar)\\b|aedar\\w*|skurf|\\balk(a|u)\\b|haftyrdil|\\bkri(a|ur)\\b|\\bskrof|stormsval|havell|straumond|\\bmukk(i|ar)\\b|\\bblik(i|ar)\\b|\\bfill\\b|kollur\\b")),

    rule("gear_lost", "gear_lost", paste0(
      "\\btap(a|_)(d|dur|dist|di|dir|dust|ur)?\\b|\\btapad\\w*|\\btapadist|\\bt(o|_)pu(d|_)(ust|u)\\b|\\bmist(um|i|ist)\\b|\\bmisstum\\b|\\btynd(ist|ust|um)\\b")),
    rule("snagged", "gear_trouble", "\\bfast(ur|ir|ar|na|nadi|nudu)?\\b|\\bfest(a|ist|u|ust|um|i)\\b|botnfest|\\bfest i\\b|fengum i skrufuna"),
    rule("torn", "gear_trouble", paste0(
      "\\brif(id|in|inn|nadi|nudu|na|_|id|i_|um|na_i)\\b|\\brifi__|\\brifid|\\bsprengt\\b|\\bgata poka|gat a (badum|odrum)|\\bgat (a|_)? ?pok|\\bgat (a|_|i) (troll|net|belg|vod|vorpu|not|nót)|^gat\\W*$|\\bstort gat|botnlaus|sprung|sprengd|sprakk|\\bopinn pok")),
    rule("tangled", "gear_trouble", "(o|_)kl(a|_)r(t|_)?\\b|_+kl_+r(t)?\\b|^okl\\W*$|\\bflaekt|\\bf(l|_)(ae|_)kt|\\banetj|\\bi klessu"),
    rule("came_loose", "gear_trouble", "fr(a|_)le(y|i)st"),
    rule("broken_part", "gear_trouble", "\\bslit(in|inn|id|nadi|nudu|na|i_)?\\b|\\bslitn|\\bbrot(in|inn|id|nadi|nudu)\\b"),
    rule("machinery", "gear_trouble", paste0(
      "velarbil|spilbil|\\bbil(l|s)?(ad|un|adi|udur|ud|adur|unar|a_|a_ur|ai|ar)\\b|\\bbiliri\\b|\\bbiladar\\b|\\bbila_ur|\\bst(y|_)ri(d)?\\b|togvind|\\bvind(a|an)\\b|\\bspil(id)?\\b")),

    rule("twin_trawl", "twin_trawl", "\\b(tv(o|_)|2) ?troll\\b|troll tv(o|_)|\\btvo veidarf|tveggja ?troll|2ja ?troll"),
    rule("single_trawl", "twin_trawl", "\\b(eitt|1) troll\\b"),

    rule("no_catch", "catch", paste0(
      "\\b(enginn|engin|ekkert|engar|engan|0) (afli|veidi|fiskur|fisk|afla|kg|skradur)\\b|",
      "^(enginn|engin|ekkert|engar|tomt|t_mt|tomur|nada|null|ekki neitt|eingin|engun|engi|enginn afli|afli enginn)\\W*$|\\bfekkst ekkert|\\bekkert (fekkst|kom|i pokanum|fiskeri|bjuga|nema|i 0)|\\btomt (hal|kast|tog)|",
      "\\be(i)?ngi(nn|mm|n)? ?(afli|fiskur)|\\bennginn|\\bafli (0|enginn|0,0)\\b|\\b(o|0),(o|0) afli|\\benginn (thorskur|fiskur)|^afli 0")),
    rule("aquaculture", "catch", "\\beldi\\b|eldis|fiskeldi|sjokvi|kviaeldi|aframeldi|\\bkvi\\b|\\bi eldi\\b"),
    rule("bait_meal", "catch", "\\bbeit(a|u)\\b|\\bi beitu\\b|\\bbraedsl|\\bmelt(u|a)\\b"),
    rule("catch_item", "catch", "oskilg|annarfiskur|\\blifur\\b|\\bhrogn\\b|\\bsvil\\b|\\bgellur|\\bkinnar\\b|\\bhausar\\b|frystikist|\\bsodi(d|n|_)\\b|\\bmeltu\\b"),
    rule("condition", "catch", "(o|_)?sl(ae|_)(g|_)(d|_|t)\\w*|blodg(ud|_d)|\\bisad\\b"),
    rule("containers", "catch", "\\b\\d+(,\\d+)?\\+? ?(p|pokar|pokum|kor|kassar|kassi|ker|tunnur)\\b|\\bp(o|_)kar\\b"),
    rule("lumpsucker_codes", "catch", "^(\\d+ ?)?(r|th|s|u|k|t|h|l)\\.?([ ,]+(\\d+ ?)?(r|th|s|u|k|t|h|l)\\.?)*\\W*$|\\b\\d+ ?(raudmag\\w*|raudm|raud)\\b|\\d+ ?(kg)?\\.? (th|u|l)\\b|\\balls (thennan|yfir|fyrir)|samt\\.? (thyngd|yfir)|oskorin|\\bkg alls\\b"),
    rule("size_quality", "catch", paste0(
      "\\bsm(a|_)tt?\\b|\\bsmafisk|\\bsmasild|\\bsm(a|_) (sild|fisk\\w*|ysa|thorsk\\w*)|\\bblanda(d|dur)\\b|\\bblondu(d|_)|",
      "\\bgod sild|\\bstor (sild|fiskur)|\\bundirm(a|_)l|\\bhorad|\\bskemmd|\\bormur|\\bataud|\\bselbit|\\bsm(a|_)(lodna|sild|luda|ludur)|\\bst(k)? ?(i )?kg\\b|\\bstk/kg|\\d+ st i kg|\\bsaemileg|\\bgott sili|\\bstort sili|\\d+ ?% undir|\\blitaafbrigd|\\bmedal(vikt|vigt|v)\\b|\\bummal\\b|\\bskorin af")),
    rule("seaweed", "catch", "\\bthar(i|a)\\b|\\btari\\b|_ara\\b|_ari\\b|thang\\b|klothang|hrossathar|marglytt|marglitt|\\bdrasl\\b|daud skel"),

    rule("codend_mesh", "gear_config", paste0(
      "\\d+ ?mm\\b|\\bpoki\\b|\\bpokinn\\b|\\bleggpok|kl(ae|_)+(d|_)ning|(th|_)orskpok|gull?la(x|xa|xakl)\\w*|\\bt-?90\\b|",
      "\\bthvernet|ferning|\\bglugg|legggluggi|\\bfiskipok|s(o|_)(d|_)upok|egersund|\\bleggp\\b|\\d+ ?mm ?pok")),
    rule("trawl_model", "gear_config", "seastar|gl(o|_)ri(a|_)|bacal(a)?o|gulltopp|\\bhoppari|ang-cos|\\bvonin\\b|\\bcosmos|\\bthorsnet|\\b(med|an) ljos|\\bljos(i)?\\b"),
    rule("grid", "gear_config", "sk(i|y)l(ja|ju|jur)\\b|sk(i|y)lja|\\bristar?\\b"),
    rule("rope_length", "gear_config", paste0(
      "\\d+ ?x ?\\d+|\\bgrandar\\w*|\\bgrand\\b|\\bvirastyr\\w*|\\bfotreip\\w*|f(o|_)treip|\\bhopparavod|\\bvod\\b|\\bbelg(ur|ir)?\\b|\\bundirbyrd\\w*|byr(d|_)i\\b")),
    rule("line_jig", "gear_config", paste0(
      "\\bs(o|_)kk(ur|va|vur|u|um|vu)\\b|\\bsakk(a|an|ur)\\b|\\bslod(i|ar|a|um)\\b|\\bkr(o|_)k(ar|um|a|ur)?\\b|\\bkr\\b|",
      "\\bbal(ar|i|a|um)\\b|\\bbjodd?\\b|stalsokk|stalsakk|handbeitt|\\bbeitt\\b|\\bs(o|a)kk?(a|ur|u)\\b|\\b\\d?s(o|_)kkur|\\bongl(a|ar|i)?\\b|\\bongull\\b|\\bleds?\\b|\\brull(ur|a|an|um)\\b|krokkar|\\bkrokar\\b")),
    rule("nets", "gear_config", "\\b\\d+ ?net(a|um|in)?\\b|\\btross(a|u|ur|um)\\b|\\blogd\\b|\\blogdum\\b|\\btr\\.? ?\\d\\b|\\blagnet|skotuselsnet|sk_tuselsnet|gr(a|_)sleppunet|\\bnetafjold"),
    rule("trap", "gear_config", "g(i|y)ldr|\\bp(o|0)tt(ar|um)\\b"),
    rule("dredge", "gear_config", "\\bplog(ur|ar|um|a|i|an)?\\b|\\bploar\\b|\\bplaeogur|\\bologur|sl(ae|_)(d|_)(a|ur|u|um|ur)\\b"),
    rule("gear_named", "gear_config", paste0(
      "^(botnvarpa|botntroll|flottroll|flotvarpa|humartroll|humarvarpa|fiskitroll|raekjutroll|raekjuvarpa|dragnot|",
      "hringnot|handfaeri|handf_ri|faeri|lina|net|not|plogur|gildrur|krabbagildrur|troll|varpa|sjostong|kafari|",
      "grasleppunet|skotuselsnet|thorsknet|graludunet|flottroll \\w+|flotroll|lo_nun_t|lodnunot|dragn_t|hringn_t|_n_t|grunn(n)?ot|notaveid\\w*|raekju ?troll\\w*|bastardur)\\W*$|hringnot ?/? ?\\(?grunn|\\bgrunn(n)?ot\\b|notaveid|tveggjatrolla|\\bath (humar|gulltopp)\\w* ?troll")),
    rule("buoy_colour", "gear_config", "^((raud|gra|gul|graen|bla|svort|hvit|blahv|bleik|appelsin|aud|bland)\\w*[ /]*)+[- /]*[\\d/]*\\W*$|^\\d+ ?- ?(raud|gra|gul|graen|bla|svort|hvit)\\w*\\W*$"),

    rule("tow_time", "effort_time", "togt(i|_)m|\\btog(ad|ud|i)? (i )?\\d+|\\d+ ?(min|minutur|m_n|klst|tima|timar|klukkut)\\b|\\bdreg(id|_) (i )?\\d|\\bkl\\.? ?\\d"),
    rule("soak", "effort_time", "\\d+\\.? ?n(a|_)tt(a|ar)?\\b|\\bnaetur\\b|\\bsolarhring|samdaegurs|\\bdreg(id|in) upp|\\btekid upp|^lagt\\b|\\bnet dregin"),
    rule("haul_count", "effort_time", "\\b\\d+ (hol|k(o|_)st)\\b|\\b(tv(o|_)|2) (hol|tog)\\b|\\bkast nr|\\b\\d+/?\\d* ?kast(i|id|inu)?\\b|\\bhol saman|\\bsamtals\\b"),

    rule("tow_direction", "place", paste0(
      "\\bdr\\.? ?(n|s|a|v|nv|na|sv|sa|nnv|vnv|asa|nna|ssv|ssa|ana|vsv|ana)\\b|\\bdr\\.? (i |til )?(nordur|sudur|austur|vestur)|",
      "\\bdreg(id|ur|um|_) (i |a |til )?(n|s|a|v|nordur|sudur|austur|vestur|nv|na|sv|sa)\\b|\\bdr\\.? ?\\d{1,3} ?(\\*|°|gr)|\\bdr (fra|i|a|med|ad)\\b|\\bd v\\b|\\d+\\* ?dr\\b|\\d+\\*\\d")),
    rule("place_name", "place", paste0(
      "sv(ae|_|a)?di\\b|\\b[a-f] sv\\w*|\\breit(ur|i)\\b|",
      L, "{3,}(dypi|dyp|grunn|grunni|banki|banka|all|alnum|hraun|hrauni|fjordur|fjardar|fj|vik|vikin|vikinni|ey|eyjar|sker|",
      "bodi|boda|kantur|kanti|flaki|flakinn|hryggur|gja|gjaa|sund|nes|holl|dypid|bleyda|blettir|slod)\\b|",
      "\\b(nordan|sunnan|vestan|austan|westan|utan|innan) (vid|vid_|i|a|af|megin|til|vert|v\\.)\\b|\\b(austast|vestast|nyrst|sydst|innst|austanmegin|vestari|eystri)\\b|",
      "^(a|n|s|v|na|nv|sa|sv|ana|nna|ne) i\\b|\\b(horn(id|inu|i)?|\\w+horn|hol(inn|num)|flak(id|i|inn)?|kantinum|kant(ur|i)|blett(ir|irnir|i)|gja(a|nna)|kapal\\w*|\\d+ ?(sml|milur|milna|milurnar))\\b|",
      "^", L, "{4,}(inn|in|id|nn|an|ar)\\W*$|^(sneidin|hallid|miklabraut|bardid|eyjan|holan|surtinn|breido|skeido|adalv\\w*|skaftar\\w*|reynis\\w*|oraefa|oshlid)\\b|",
      "^(a|n|s|v|na|nv|sa|sv|nnv|vnv|ssv) (i |vid |af |a |fra )?(?!ekki|ad |thad|thvi|thessu|land|morgun|sama|leid)", L, "{3,}")),
    rule("fathoms", "place", "\\d+ ?(-|til) ?\\d+ ?fm|\\d+ ?fm\\b|\\bfadm|\\bfm\\b"),
    rule("distance", "place", "\\d+ ?sjm|\\bsjomil"),

    rule("weather", "environment", paste0(
      "br(ae|_)l(a|u)|\\bvedur|vedri|vedurs|\\bhvass|\\bstorm|haegvidri|\\bkaldi\\b|\\bvind(ur|i|s)\\b|\\bsjolag|",
      "\\bmikill sjor|\\balda\\b|\\bisrek|_srek|\\bising|\\bthoka\\b|_oka\\b|\\bmyrk(ur|ri)|\\bsnjo|gar(d|_)s+jor|\\bblid(a|u)\\b|^logn\\W*$|\\bdokkur sjor|\\bveltingur|l(o|_)na(d|_)\\b|^haegvidri")),
    rule("temperature", "environment", "°c|\\bheitur sjor|kaldur sjor|iskaldur|sjavarhit|\\bhiti (a|vid) hofudl|hitanemi|\\bsjor \\d"),
    rule("current", "environment", "straum|falla ?sk(i|y)(p|f)ti"),
    rule("bottom", "environment", "\\bdrull|\\bgrj(o|_)t|\\bleir\\b|\\bsandur|\\bhard(ur)? botn|\\bslaemur botn|\\bkorall|\\bsvamp"),

    rule("paper_logbook", "admin", "^(bok|bokin|papp(i|_)r)\\W*$|papp(i|_)r|\\bskrad (a|i) bok|\\bi bok\\b|\\bbokin\\b|\\bafladagbok\\w*"),
    rule("app_system", "admin", paste0(
      "\\bapp(id|inu|i)?\\b|\\btolv(a|u|unni)\\b|\\bhafsyn|\\buppfaer|\\bkerfi\\w*|\\bforrit|\\bsend(a|i|ist|t)\\b|",
      "\\bskil(a|um|in|ad)\\b|\\bvirkar ekki|virka.?i ekki|\\bnetsamband|\\bsamband\\b|tolvuves|endursen|stadfest|\\bvesen\\b|hledur ekki|taekni|\\bsent\\b|fyrsta sinn|forit bila|teljari|\\bfikt\\b|\\bkrani\\b")),
    rule("date_or_report", "admin", "^\\d{1,2}\\.\\d{1,2}\\.(\\d{2}|\\d{4})\\W*$|\\baflaskra|^\\d{1,2} (jan|feb|mar|apr|mai|jun|jul|ag|sep|okt|nov|des)\\w*\\W*$"),
    rule("entered_by", "admin", "\\bbth\\b|gbth|\\bskrad af\\b|nyskrad|yfirskrifa"),
    rule("vessel_substitute", "admin", "\\bkom i stad|gamli baturinn|\\bannar batur|^verid i f(r|_)|f(ae|_)reysku ?landhelg|\\bverid i fro"),
    rule("confidential", "admin", "trunadarmal|tr_na_arm_l"),
    rule("legal_quota", "admin", "kvot|\\blagnalokun|\\bleyfi\\b|\\bundanthag|\\breglugerd|\\blokad|\\blokun|\\bskyndilok|\\bfridun|\\bfridad"),
    rule("landing_trip", "admin", "\\bland(ad|i|adi|adur|anir)\\b|\\blondun\\w*|\\bi land\\b|\\bhofn(in|ina|inni)?\\b|\\bveidiferd\\w*|\\brodur\\b|\\brodri\\b"),
    rule("crew_contact", "admin", "skil ekki|\\bdregi(d|_) fyrir [a-z_]+ [a-z_]+|skipstjor|\\bstyrimad|\\bkvedj|\\bafsokun|\\bbidst|\\bforlat|\\bfyrirgef|\\bkv\\.? \\w"),
    rule("stoppage", "admin", "\\bvinnsl\\w*|\\bstoppad\\w*|\\bstopp\\b|\\bhaett(um|ur)?\\b|\\bhlé|\\bhle\\b|vei(d|_)um h(ae|_)tt|veidum lokid|\\bstrand|millilondun|ekki landa"),
    rule("no_gear_lost", "admin", "\\beng(in|inn|i|um) (veidarfaeri|veidafaeri)\\w* (topud|tapast|tapad|topu)|\\bengi topud"),

    rule("placeholder", "unclear", paste0(
      "^\\W*$|^[a-z_]{1,2}\\W*$|^\\d+([.,]\\d+)?\\W*$|^\\d+([.,]\\d+)? ?(-|/) ?\\d+([.,]\\d+)?\\W*$|",
      "^(ok|ja|nei|x+|n/a|all good|allt gott|allt\\.?gekk vel|buid|buum|bumm|b(u|_)mm|b__mm|tonn|land|ekki|athugasemd engin|engin athugasemd|(a )?ekki vid|litid|all)\\W*$|^[\\d\\W]+$|\\b\\d+x? ?bumm\\b|^\\d+ ?(kg|tonn|t)\\W*$"))
  )
  r$priority <- match(r$class, names(note_classes()))
  stopifnot(!anyNA(r$priority))
  r
}

# Species named in a note (folded), with the landings' code; NA where the list has none.
note_species <- function() {
  rbind(
    data.frame(sp = "cod",               code = 1,   pat = "(th|_)orsk(?!pok)\\w*|\\bthors\\b"),
    data.frame(sp = "haddock",           code = 2,   pat = "\\bys(a|u|unni|an)\\b|\\b_s(a|u)\\b"),
    data.frame(sp = "saithe",            code = 3,   pat = "\\bufs(i|a|inn)\\b"),
    data.frame(sp = "redfish",           code = 5,   pat = "\\bkarf(i|a|inn)\\b|gullkarf"),
    data.frame(sp = "ling",              code = 6,   pat = "\\blong(u|una)\\b|\\blanga\\b"),
    data.frame(sp = "blue ling",         code = 7,   pat = "blal(o|a)ng"),
    data.frame(sp = "tusk",              code = 8,   pat = "\\bkeil(a|u)\\b"),
    data.frame(sp = "Atlantic wolffish", code = 9,   pat = "steinbit"),
    data.frame(sp = "roundnose grenadier", code = 10, pat = "langhal"),
    data.frame(sp = "starry ray",        code = 12,  pat = "tindab|tindaskat"),
    data.frame(sp = "spotted wolffish",  code = 13,  pat = "\\bhl(y|_)r(i|a|um)\\b"),
    data.frame(sp = "monkfish",          code = 14,  pat = "sk(o|_)tusel"),
    data.frame(sp = "skate",             code = 15,  pat = "\\bsk(a|_)t(a|u)\\b|\\bskotu\\b"),
    data.frame(sp = "spurdog",           code = 16,  pat = "\\bhafur\\b"),
    data.frame(sp = "Greenland shark",   code = 17,  pat = "(?<!bein)h(a|_)karl|\\bgsk\\b"),
    data.frame(sp = "porbeagle",         code = 18,  pat = "h(a|_)mer(i|a|u|ur)?\\b"),
    data.frame(sp = "basking shark",     code = NA,  pat = "beinh(a|_)karl"),
    data.frame(sp = "argentine",         code = 19,  pat = "gul+(l)?ax"),
    data.frame(sp = "halibut",           code = 21,  pat = "(?<!gra)(?<!gra )l(u|_)d(a|u|ur|um|una|unni|urnar)\\b|hvitl(u|_)d"),
    data.frame(sp = "Greenland halibut", code = 22,  pat = "gral(u|_)d"),
    data.frame(sp = "plaice",            code = 23,  pat = "skarkol"),
    data.frame(sp = "lemon sole",        code = 24,  pat = "solkol"),
    data.frame(sp = "dab",               code = 27,  pat = "sandkol"),
    data.frame(sp = "herring",           code = 30,  pat = "s(i|_)ld(?!ar ?prufa)\\w*|\\bher\\b|\\bnsild|\\bnisl\\b|\\btsild|norsk.?(i|_)slensk"),
    data.frame(sp = "capelin",           code = 31,  pat = "\\blo(d|_)n(a|u|an)\\b|\\bcap\\b"),
    data.frame(sp = "blue whiting",      code = 34,  pat = "kolmun\\w*|\\bkolm\\b|\\bwhb\\b"),
    data.frame(sp = "mackerel",          code = 36,  pat = "\\bma(k|c)\\b|\\bmakr\\w*|\\bmakil\\w*|\\bmakrel\\w*"),
    data.frame(sp = "Nephrops",          code = 40,  pat = "\\bhumar"),
    data.frame(sp = "shrimp",            code = 41,  pat = "r(ae|_)kj"),
    data.frame(sp = "scallop",           code = 43,  pat = "horpudisk"),
    data.frame(sp = "lumpsucker",        code = 48,  pat = "hrognkels|grasleppa|grasleppu|raudmag|\\braudm\\b"),
    data.frame(sp = "pearlside",         code = 130, pat = "gulldepl"),
    data.frame(sp = "sea urchin",        code = 191, pat = "igulker"),
    data.frame(sp = "sea cucumber",      code = 199, pat = "s(ae|_)bj(u|_)g"),
    data.frame(sp = "rock crab",         code = 689, pat = "grjotkrabb"),
    data.frame(sp = "harbour porpoise",  code = 1026, pat = "hn(i|y|_)s(a|ur|u|um|an)\\b"),
    data.frame(sp = "seal",              code = 1051, pat = "\\bsel(ur|ir|i|um|s|inn)?\\b|landsel|utsel"),
    data.frame(sp = "whale",             code = NA,  pat = "\\bhval|hrefn|hnufubak|grindhv"),
    data.frame(sp = "bird",              code = NA,  pat = paste0("fugl(?!afj)|\\baed(ur|i|ar)\\b|aedarfug|aedafug|\\bkoll(a|ur|u)\\b|teist|svartfug|skarf|",
                                                               "\\bsul(a|ur|u)\\b|\\bfyl(l|ar)\\b|\\blund(i|ar)\\b|\\bmaf(ur|ar)\\b|langvi|\\balk(a|u)\\b|haftyrdil")))
}

# classify_notes() — one row per note: its main class, its tags and the species it names (comma-separated).
#   text           the notes as entered
#   bycatch_table  TRUE where the note sits in a mammal and bird bycatch table: it is about that animal, whatever it says
# Precedence beyond the table: a freezing test is not MFRI's sample; live fish into a farm are not released; a codend
# named only in "gat á poka" is the trouble, not the configuration; "no gear lost" is not gear lost. A call sign names a
# vessel (class transfer where no rule matched); a species alone is catch.
classify_notes <- function(text, bycatch_table = FALSE) {
  rules <- note_rules(); classes <- names(note_classes()); species <- note_species()
  f <- note_fold(ifelse(is.na(text), "", text))
  u <- unique(f)
  hit <- vapply(rules$pattern, function(p) grepl(p, u, perl = TRUE), logical(length(u)))
  if (!is.matrix(hit)) hit <- matrix(hit, nrow = length(u))
  colnames(hit) <- rules$tag
  hit[hit[, "processing_test"], "mfri_sample"] <- FALSE
  hit[hit[, "aquaculture"], "released"] <- FALSE
  hit[hit[, "no_gear_lost"], "gear_lost"] <- FALSE
  trouble_codend <- grepl("gat (a|_)? ?pok|botnlaus pok|sprung\\w* pok|rifinn pok|opinn pok", u, perl = TRUE) &
    !grepl("\\d+ ?mm|leggpok|(th|_)orskpok|gull?la", u, perl = TRUE)
  hit[trouble_codend, "codend_mesh"] <- FALSE
  sp_hit <- vapply(species$pat, function(p) grepl(p, u, perl = TRUE), logical(length(u)))
  if (!is.matrix(sp_hit)) sp_hit <- matrix(sp_hit, nrow = length(u))
  sp <- apply(sp_hit, 1, function(r) paste(species$sp[r], collapse = ","))
  extra <- cbind(vessel_callsign = grepl("\\btf[ .-]?[a-z][ .-]?[a-z]{1,2}\\b", u, perl = TRUE),
                 species_amount = nzchar(sp) & grepl("\\d", u), species_named = nzchar(sp) & !grepl("\\d", u))
  extra_class <- c(vessel_callsign = "transfer", species_amount = "catch", species_named = "catch")
  tags <- vapply(seq_along(u), function(i) paste(c(rules$tag[hit[i, ]], colnames(extra)[extra[i, ]]), collapse = ","), "")
  prio <- apply(hit, 1, function(r) if (any(r)) min(rules$priority[r]) else NA_integer_)
  for (k in colnames(extra)) { take <- is.na(prio) & extra[, k]; prio[take] <- match(extra_class[[k]], classes) }
  prio[is.na(prio)] <- length(classes)
  i <- match(f, u)
  out <- data.frame(note_class = classes[prio][i], note_tags = tags[i], note_species = sp[i])
  byc <- rep_len(bycatch_table, length(text)) & out$note_class %in% c("other", "unclear", "catch", "effort_time")
  out$note_class[byc] <- "sensitive_bycatch"
  out$note_tags[byc] <- ifelse(nzchar(out$note_tags[byc]), paste0(out$note_tags[byc], ",bycatch_detail"), "bycatch_detail")
  out
}
