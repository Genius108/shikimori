class Neko::IsAllowed
  method_object :anime

  EN_RECAP = [
    'recap',
    'recaps',
    'compilation movie',
    'picture drama',
    'vr',
    'chibi'
  ]
  RU_RECAP = [
    'рекап',
    'обобщение',
    'чиби',
    'краткое содержание'
  ]

  EN_RECAP_REGEXP = /\b(?:#{EN_RECAP.join('|')})\b/i
  RU_RECAP_REGEXP = /\b(?:#{RU_RECAP.join('|')})\b/i

  ALL_RECAP_REGEXP = /\b(?:#{(EN_RECAP + RU_RECAP).join('|')})\b/i

  def call
    allowed_in_neko? || !(
      @anime.anons? ||
      (special? && recap_name?)
    )
  end

private

  def allowed_in_neko?
    neko_rule.rule.dig(:generator, 'not_ignored_ids')&.include? anime.id
  end

  def neko_rule
    NekoRepository.instance.find @anime.franchise, 1
  end

  def special?
    @anime.kind_special? || @anime.kind_ova?
  end

  def recap_name?
    @anime.name.match?(ALL_RECAP_REGEXP) ||
      @anime.english&.match?(EN_RECAP_REGEXP) ||
      @anime.russian&.match?(RU_RECAP_REGEXP) ||
      @anime.description_en&.match?(EN_RECAP_REGEXP) ||
      @anime.description_ru&.match?(RU_RECAP_REGEXP)
  end
end
