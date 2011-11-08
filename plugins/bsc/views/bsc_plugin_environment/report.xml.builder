xml.instruct!
xml.Relatorio do
  xml.Resumo do
    xml.TotalBSC(@bscs.all.count)
    xml.Periodo do
      xml.DataInicio(@to.strftime('%d%m%Y'))
      xml.DataFim(@from.strftime('%d%m%Y'))
    end
  end
  xml.BSCs do
    @bscs.each do |bsc|
      xml.BSC do
        xml.RazaoSocial(bsc.company_name)
        xml.TotalEmpreendimentos(bsc.enterprises.count)
        xml.Empreendimentos do
          bsc.enterprises.each do |enterprise|
            xml.Empreendimento do
              xml.RazaoSocial(enterprise.company_name)
              xml.Produtos do
                enterprise.products.each do |product|
                  xml.Produto(product.name)
                end
              end
            end
          end
        end
        xml.Conteudos do
          contents = bsc.articles.created_between(@from, @to)
          xml.TotalProduzido(contents.count)
          contents.group_by {|content| content.class.name }.each do |grouper, items| 
            xml.Conteudo(items.count, "tipo" => grouper)
          end
        end
        xml.Contratos do
          contracts = bsc.contracts.created_between(@from, @to)
          xml.Total(contracts.count)
          contracts.each do |contract|
            xml.Contrato do
              xml.TipoComprador(contract_client_type_to_name(contract.client_type))
              xml.LocalComprador([contract.city,contract.state].compact.join('-'))
              xml.TipoContrato(contract_business_type_to_name(contract.business_type))
              xml.Situacao(contract_status_to_name(contract.status))
              xml.NumeroAgricultores(contract.number_of_producers)
              xml.NumeroEmpreendimentos(contract.enterprises.count)
              xml.NumeroProdutos(contract.products.count)
            end
          end
        end
      end
    end
  end
end
