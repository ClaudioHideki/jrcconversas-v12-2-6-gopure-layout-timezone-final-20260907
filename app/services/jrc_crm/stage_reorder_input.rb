module JrcCrm
  module StageReorderInput
    module_function

    def call(entries)
      raise ArgumentError, 'Informe uma lista de etapas.' unless entries.is_a?(Array) && entries.any?

      ids = entries.map { |row| positive_integer(row, :id) }
      positions = entries.map { |row| positive_integer(row, :position) }
      if ids.uniq.length != ids.length || positions.uniq.length != positions.length
        raise ArgumentError, 'Informe etapas e posições únicas.'
      end
      [ids, positions]
    end

    def positive_integer(row, key)
      raise ArgumentError, 'Etapa e posição devem ser inteiros positivos.' unless row.respond_to?(:key?)

      value = row[key] || row[key.to_s]
      text = value.to_s
      unless /\A[0-9]+\z/.match?(text) && text.to_i.positive?
        raise ArgumentError, 'Etapa e posição devem ser inteiros positivos.'
      end
      Integer(text, 10)
    end
    private_class_method :positive_integer
  end
end
