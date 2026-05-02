function Propostas() {
  const api = useApi();
  const [propostas, setPropostas] = useState([]);
  const [clientes, setClientes] = useState([]);
  const [precos, setPrecos] = useState([]);
  const [showForm, setShowForm] = useState(false);
  const [showPrecos, setShowPrecos] = useState(false);
  const [editandoPreco, setEditandoPreco] = useState(null);
  const [precosEdit, setPrecosEdit] = useState({});

  // Form da proposta
  const [form, setForm] = useState({
    cliente_id:'', titulo:'', cnpj:'', agencia:'',
    periodo_inicio:'', periodo_fim:'', observacoes:'',
    midias_selecionadas: [] // [{midia_id, midia_nome, tipo, dias_horas_periodos, preco_unit, preco_total, unidade, editado}]
  });

  // Mídia sendo adicionada
  const [midiaAdd, setMidiaAdd] = useState({
    precoId: '', quantidade: 1, precoCustom: ''
  });

  const load = () => {
    api.get('/propostas').then(setPropostas).catch(()=>[]);
    api.get('/clientes').then(setClientes).catch(()=>[]);
    api.get('/precos').then(setPrecos).catch(()=>[]);
  };
  useEffect(()=>{ load(); },[]);

  // Calcular preço de uma mídia com base na quantidade
  function calcularPreco(preco, quantidade) {
    if (!preco || !quantidade) return 0;
    const qty = parseInt(quantidade) || 1;

    if (preco.tipo === 'diaria') {
      let precoDia = parseFloat(preco.preco_1);
      if (qty >= 7 && preco.preco_7mais)       precoDia = parseFloat(preco.preco_7mais);
      else if (qty >= 2 && preco.preco_2_6)    precoDia = parseFloat(preco.preco_2_6);
      return precoDia * qty;
    }

    if (preco.tipo === 'pacote30') {
      const base = parseFloat(preco.preco_1);
      if (qty >= 2) {
        const desc = parseFloat(preco.desconto_multi || 10) / 100;
        return base * qty * (1 - desc);
      }
      return base * qty;
    }

    if (preco.tipo === 'hora') {
      const baseHora = parseFloat(preco.preco_1);
      if (qty >= 6) {
        const desc = parseFloat(preco.desconto_6h || 30) / 100;
        return baseHora * qty * (1 - desc);
      }
      return baseHora * qty;
    }

    return 0;
  }

  function labelQuantidade(tipo) {
    if (tipo === 'diaria')   return 'Dias';
    if (tipo === 'pacote30') return 'Períodos (30 dias cada)';
    if (tipo === 'hora')     return 'Horas';
    return 'Quantidade';
  }

  function precoUnitLabel(preco, quantidade) {
    if (!preco) return '';
    const qty = parseInt(quantidade) || 1;
    if (preco.tipo === 'diaria') {
      let p = parseFloat(preco.preco_1);
      let faixa = '1 dia';
      if (qty >= 7 && preco.preco_7mais)    { p = parseFloat(preco.preco_7mais); faixa = '7+ dias'; }
      else if (qty >= 2 && preco.preco_2_6) { p = parseFloat(preco.preco_2_6);  faixa = '2-6 dias'; }
      return `R$ ${p.toLocaleString('pt-BR',{minimumFractionDigits:2})} / dia (faixa: ${faixa})`;
    }
    if (preco.tipo === 'pacote30') {
      const p = parseFloat(preco.preco_1);
      const desc = preco.desconto_multi || 10;
      return qty >= 2
        ? `R$ ${p.toLocaleString('pt-BR',{minimumFractionDigits:2})} × ${qty} períodos − ${desc}% = desconto aplicado`
        : `R$ ${p.toLocaleString('pt-BR',{minimumFractionDigits:2})} / período 30 dias`;
    }
    if (preco.tipo === 'hora') {
      const p = parseFloat(preco.preco_1);
      const desc = preco.desconto_6h || 30;
      return qty >= 6
        ? `R$ ${p.toLocaleString('pt-BR',{minimumFractionDigits:2})} / hora × ${qty}h − ${desc}% pacote`
        : `R$ ${p.toLocaleString('pt-BR',{minimumFractionDigits:2})} / hora`;
    }
    return '';
  }

  function adicionarMidia() {
    const preco = precos.find(p => p.id === midiaAdd.precoId);
    if (!preco) return alert('Selecione uma mídia');
    const qty = parseInt(midiaAdd.quantidade) || 1;
    if (qty <= 0) return alert('Quantidade deve ser maior que zero');

    const totalAuto = calcularPreco(preco, qty);
    const totalFinal = midiaAdd.precoCustom ? parseFloat(midiaAdd.precoCustom.replace(',','.')) : totalAuto;

    const item = {
      midia_id:    preco.id,
      midia_nome:  preco.midia_nome,
      tipo:        preco.tipo,
      quantidade:  qty,
      unidade:     preco.unidade,
      preco_unit:  parseFloat(preco.preco_1),
      preco_total: totalFinal,
      preco_auto:  totalAuto,
      editado:     !!midiaAdd.precoCustom,
      label_unit:  precoUnitLabel(preco, qty),
    };

    setForm(p => ({
      ...p,
      midias_selecionadas: [...p.midias_selecionadas, item]
    }));
    setMidiaAdd({ precoId:'', quantidade:1, precoCustom:'' });
  }

  function removerMidia(idx) {
    setForm(p => ({
      ...p,
      midias_selecionadas: p.midias_selecionadas.filter((_,i) => i !== idx)
    }));
  }

  function editarPrecoMidia(idx, novoValor) {
    setForm(p => {
      const arr = [...p.midias_selecionadas];
      arr[idx] = { ...arr[idx], preco_total: parseFloat(novoValor.replace(',','.')) || 0, editado: true };
      return { ...p, midias_selecionadas: arr };
    });
  }

  const totalProposta = form.midias_selecionadas.reduce((a,m) => a + (m.preco_total || 0), 0);

  async function salvar() {
    if (!form.cliente_id || !form.titulo) return alert('Cliente e título obrigatórios');
    if (form.midias_selecionadas.length === 0) return alert('Adicione pelo menos uma mídia');
    try {
      const payload = {
        cliente_id:    form.cliente_id,
        titulo:        form.titulo,
        cnpj:          form.cnpj || '',
        agencia:       form.agencia || '',
        periodo_inicio: form.periodo_inicio || null,
        periodo_fim:   form.periodo_fim || null,
        valor:         totalProposta,
        observacoes:   form.observacoes || '',
        midias:        form.midias_selecionadas.map(m => ({
          nome:        m.midia_nome,
          quantidade:  m.quantidade,
          tipo:        m.tipo,
          preco_total: m.preco_total,
          unidade:     m.unidade,
          label_unit:  m.label_unit,
          editado:     m.editado,
        }))
      };
      const res = await api.post('/propostas', payload);
      if (res.erro) { alert('Erro: ' + res.erro); return; }
      setShowForm(false);
      setForm({ cliente_id:'', titulo:'', cnpj:'', agencia:'', periodo_inicio:'', periodo_fim:'', observacoes:'', midias_selecionadas:[] });
      load();
    } catch(e) { alert('Erro: ' + e.message); }
  }

  // Editar tabela de preços
  async function salvarPreco(id) {
    const ed = precosEdit[id];
    if (!ed) return;
    try {
      await api.put('/precos/' + id, ed);
      setEditandoPreco(null);
      load();
      alert('Preço atualizado!');
    } catch(e) { alert('Erro: ' + e.message); }
  }

  async function mudarStatus(id, status) {
    try {
      await api.put('/propostas/'+id+'/status', { status });
      load();
    } catch(e) { alert('Erro: ' + e.message); }
  }

  async function aprovar(id) {
    if (!window.confirm('Aprovar esta proposta? Isso gerará um PI, Produção e Cobrança automaticamente.')) return;
    try {
      const res = await api.put('/propostas/'+id+'/status', { status:'Aprovada' });
      if (res.erro) { alert('Erro: ' + res.erro); return; }
      load();
      const proposta = propostas.find(p=>p.id===id) || {};
      const clienteData = clientes.find(c=>c.id===proposta.cliente_id) || {};
      setTimeout(()=>{
        if (window.confirm('Proposta aprovada! Deseja gerar o PDF financeiro agora?')) {
          gerarPDFFinanceiro({...proposta}, res.pi, clienteData);
        }
      }, 500);
    } catch(e) { alert('Erro: ' + e.message); }
  }

  function gerarPDFProposta(proposta) {
    const cliente = clientes.find(c=>c.id===proposta.cliente_id) || {};
    const midias = proposta.midias || [];
    const dataHora = new Date().toLocaleString('pt-BR');
    const periodoInicio = proposta.periodo_inicio ? new Date(proposta.periodo_inicio).toLocaleDateString('pt-BR') : '—';
    const periodoFim    = proposta.periodo_fim    ? new Date(proposta.periodo_fim).toLocaleDateString('pt-BR')    : '—';

    const linhasMidias = midias.map(function(m) {
      return '<tr>'
        + '<td style="padding:10px 12px;border-bottom:1px solid #eee;font-weight:600">' + (m.nome||m) + '</td>'
        + '<td style="padding:10px 12px;border-bottom:1px solid #eee;color:#888">' + (m.unidade||'') + '</td>'
        + '<td style="padding:10px 12px;border-bottom:1px solid #eee;text-align:center">' + (m.quantidade||1) + '</td>'
        + '<td style="padding:10px 12px;border-bottom:1px solid #eee;color:#888;font-size:11px">' + (m.label_unit||'') + '</td>'
        + '<td style="padding:10px 12px;border-bottom:1px solid #eee;text-align:right;font-weight:700;color:#1a237e">'
        + 'R$ ' + Number(m.preco_total||0).toLocaleString('pt-BR',{minimumFractionDigits:2})
        + (m.editado ? ' <span style="font-size:10px;color:#f59e0b">(editado)</span>' : '')
        + '</td></tr>';
    }).join('');

    const html = '<!DOCTYPE html><html><head><meta charset="UTF-8"><title>Proposta ' + proposta.numero + '</title>'
      + '<style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:Arial,sans-serif;font-size:13px;padding:40px;color:#222}'
      + '.header{display:flex;justify-content:space-between;align-items:flex-start;border-bottom:3px solid #1a237e;padding-bottom:20px;margin-bottom:28px}'
      + '.logo{font-size:22px;font-weight:900;color:#1a237e}.badge{display:inline-block;padding:3px 10px;border-radius:20px;font-size:11px;font-weight:700;background:#e8eaf6;color:#1a237e}'
      + '.grid{display:grid;grid-template-columns:1fr 1fr 1fr;gap:12px;margin-bottom:20px}'
      + '.field label{font-size:10px;color:#888;text-transform:uppercase;display:block;margin-bottom:2px}'
      + '.field span{font-size:13px;font-weight:600}'
      + 'table{width:100%;border-collapse:collapse}th{text-align:left;padding:10px 12px;background:#f8fafc;font-size:11px;text-transform:uppercase;color:#888;border-bottom:2px solid #e2e8f0}'
      + '.total-box{display:flex;justify-content:flex-end;margin-top:16px}'
      + '.total-inner{background:#1a237e;color:white;padding:14px 24px;border-radius:10px;text-align:center}'
      + '.total-inner label{font-size:11px;opacity:0.7;display:block;margin-bottom:4px}'
      + '.total-inner span{font-size:26px;font-weight:900}'
      + '.footer{margin-top:40px;border-top:1px solid #eee;padding-top:16px;font-size:11px;color:#888;display:flex;justify-content:space-between}'
      + '.assin{margin-top:50px;display:grid;grid-template-columns:1fr 1fr;gap:40px}'
      + '.assin-campo{border-top:1px solid #333;padding-top:8px;text-align:center;font-size:11px}'
      + '.obs{background:#fffbeb;border:1px solid #fcd34d;border-radius:8px;padding:12px;margin-top:16px;font-size:12px}'
      + '</style></head><body>'
      + '<div class="header"><div><div class="logo">Exfera Mídia OOH</div><div style="font-size:11px;color:#666;margin-top:4px">Proposta Comercial</div></div>'
      + '<div style="text-align:right"><div style="font-size:16px;font-weight:800;color:#1a237e">PROPOSTA COMERCIAL</div>'
      + '<div style="font-size:13px;font-weight:700;color:#666;margin-top:4px">' + proposta.numero + '</div>'
      + '<span class="badge">' + proposta.status + '</span></div></div>'
      + '<div class="grid">'
      + '<div class="field"><label>Cliente</label><span>' + (cliente.empresa || proposta.cliente_nome || '—') + '</span></div>'
      + '<div class="field"><label>CNPJ</label><span>' + (proposta.cnpj || '—') + '</span></div>'
      + '<div class="field"><label>Agência</label><span>' + (proposta.agencia || '—') + '</span></div>'
      + '<div class="field"><label>Campanha</label><span>' + proposta.titulo + '</span></div>'
      + '<div class="field"><label>Período Início</label><span>' + periodoInicio + '</span></div>'
      + '<div class="field"><label>Período Fim</label><span>' + periodoFim + '</span></div>'
      + '</div>'
      + '<table><thead><tr>'
      + '<th>Mídia</th><th>Especificação</th><th style="text-align:center">Qtd</th><th>Detalhes</th><th style="text-align:right">Valor</th>'
      + '</tr></thead><tbody>'
      + linhasMidias
      + '</tbody></table>'
      + '<div class="total-box"><div class="total-inner"><label>VALOR TOTAL DA PROPOSTA</label>'
      + '<span>R$ ' + Number(proposta.valor||0).toLocaleString('pt-BR',{minimumFractionDigits:2}) + '</span></div></div>'
      + (proposta.observacoes ? '<div class="obs"><strong>Observações:</strong> ' + proposta.observacoes + '</div>' : '')
      + '<div class="assin"><div class="assin-campo">Responsável Comercial / Data</div><div class="assin-campo">Cliente / Data</div></div>'
      + '<div class="footer"><span>Gerado em ' + dataHora + ' via Exfera OOH Manager</span><span>' + proposta.numero + ' | ' + proposta.titulo + '</span></div>'
      + '<script>window.onload=function(){window.print();}<\/script>'
      + '</body></html>';

    const win = window.open('', '_blank', 'width=1000,height=750');
    win.document.write(html);
    win.document.close();
  }

  function gerarPDFFinanceiro(proposta, pi, cliente) {
    const win = window.open('', '_blank', 'width=900,height=700');
    const piNum = pi ? pi.numero : (proposta.numero || '');
    const empresa = cliente ? (cliente.empresa || '') : (proposta.cliente_nome || '');
    const valor = Number(proposta.valor || 0).toLocaleString('pt-BR', {style:'currency', currency:'BRL'});
    const dataHora = new Date().toLocaleString('pt-BR');
    const periodoInicio = proposta.periodo_inicio ? new Date(proposta.periodo_inicio).toLocaleDateString('pt-BR') : '—';
    const periodoFim    = proposta.periodo_fim    ? new Date(proposta.periodo_fim).toLocaleDateString('pt-BR')    : '—';
    const midias = (proposta.midias || []).map(function(m){
      return '<span style="background:#1a237e;color:white;padding:4px 12px;border-radius:20px;font-size:11px;font-weight:600;margin:2px">'
        + (m.nome||m) + (m.quantidade > 1 ? ' ×'+m.quantidade : '') + '</span>';
    }).join('');

    const html = '<!DOCTYPE html><html><head><meta charset="UTF-8"><title>Doc Financeiro</title>'
      + '<style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:Arial,sans-serif;font-size:13px;padding:40px}'
      + '.header{display:flex;justify-content:space-between;border-bottom:3px solid #e63946;padding-bottom:20px;margin-bottom:24px}'
      + '.logo{font-size:20px;font-weight:900;color:#e63946}.grid{display:grid;grid-template-columns:1fr 1fr 1fr;gap:12px;margin-bottom:20px}'
      + '.field label{font-size:10px;color:#888;text-transform:uppercase;display:block;margin-bottom:2px}.field span{font-size:13px;font-weight:600}'
      + '.vbox{background:#f8f8f8;border:1px solid #eee;border-radius:6px;padding:10px 16px;text-align:center}'
      + '.vbox label{font-size:10px;color:#888;text-transform:uppercase;display:block;margin-bottom:4px}'
      + '.big{font-size:28px;font-weight:900;color:#e63946}'
      + '.footer{margin-top:40px;border-top:1px solid #eee;padding-top:16px;font-size:11px;color:#888;display:flex;justify-content:space-between}'
      + '.assin{margin-top:50px;display:grid;grid-template-columns:1fr 1fr;gap:40px}'
      + '.assin-campo{border-top:1px solid #222;padding-top:8px;text-align:center;font-size:11px}'
      + '</style></head><body>'
      + '<div class="header"><div><div class="logo">OOHManager</div><div style="font-size:11px;color:#666;margin-top:4px">Documento Financeiro</div></div>'
      + '<div style="text-align:right"><div style="font-size:16px;font-weight:700;color:#e63946">DOCUMENTO FINANCEIRO</div>'
      + '<div style="font-size:12px;color:#666;margin-top:4px">' + piNum + '</div></div></div>'
      + '<div class="grid">'
      + '<div class="field"><label>Empresa</label><span>' + empresa + '</span></div>'
      + '<div class="field"><label>CNPJ</label><span>' + (proposta.cnpj||'—') + '</span></div>'
      + '<div class="field"><label>Agência</label><span>' + (proposta.agencia||'—') + '</span></div>'
      + '<div class="field"><label>Campanha</label><span>' + (proposta.titulo||'') + '</span></div>'
      + '<div class="field"><label>Período</label><span>' + periodoInicio + ' a ' + periodoFim + '</span></div>'
      + '<div class="field"><label>PI</label><span>' + piNum + '</span></div>'
      + '</div>'
      + '<div style="margin-bottom:20px"><div style="font-size:10px;color:#888;text-transform:uppercase;margin-bottom:8px">Mídias Contratadas</div>'
      + '<div style="display:flex;flex-wrap:wrap;gap:6px">' + midias + '</div></div>'
      + '<div style="display:grid;grid-template-columns:1fr 1fr 1fr;gap:16px;margin-bottom:20px">'
      + '<div class="vbox"><label>Valor Total</label><div class="big">' + valor + '</div></div>'
      + '<div class="vbox"><label>Data</label><div style="font-size:18px;font-weight:700">' + new Date().toLocaleDateString('pt-BR') + '</div></div>'
      + '<div class="vbox"><label>Status</label><div style="font-size:16px;font-weight:700;color:#16a34a">APROVADO</div></div>'
      + '</div>'
      + '<div class="assin"><div class="assin-campo">Resp. Comercial / Data</div><div class="assin-campo">Resp. Financeiro / Data</div></div>'
      + '<div class="footer"><span>Gerado em ' + dataHora + '</span><span>' + piNum + ' | ' + (proposta.titulo||'') + '</span></div>'
      + '<script>window.onload=function(){window.print();}<\/script>'
      + '</body></html>';
    win.document.write(html);
    win.document.close();
  }

  const fmtR = v => 'R$ ' + Number(v||0).toLocaleString('pt-BR',{minimumFractionDigits:2});

  // Agrupar preços por tipo para exibição
  const precosPorTipo = {
    diaria:   precos.filter(p => p.tipo === 'diaria'),
    pacote30: precos.filter(p => p.tipo === 'pacote30'),
    hora:     precos.filter(p => p.tipo === 'hora'),
  };

  return (
    <div>
      <div style={{display:'flex',justifyContent:'space-between',alignItems:'center',marginBottom:20}}>
        <h2 style={{fontSize:20,fontWeight:700}}>Propostas Comerciais</h2>
        <div style={{display:'flex',gap:8}}>
          <Btn variant="ghost" onClick={()=>setShowPrecos(!showPrecos)} style={{fontSize:12}}>
            {showPrecos ? 'Fechar Tabela' : '💲 Tabela de Preços'}
          </Btn>
          <Btn onClick={()=>setShowForm(!showForm)}>+ Nova Proposta</Btn>
        </div>
      </div>

      {/* TABELA DE PREÇOS EDITÁVEL */}
      {showPrecos && (
        <div style={{...s.card,marginBottom:20,borderLeft:'4px solid #7c3aed'}}>
          <h3 style={{fontSize:14,fontWeight:700,marginBottom:16,color:'#7c3aed'}}>Tabela de Preços — Clique em Editar para alterar</h3>

          {/* DIÁRIAS */}
          <div style={{marginBottom:20}}>
            <div style={{fontSize:11,fontWeight:700,color:C.muted,textTransform:'uppercase',letterSpacing:'0.06em',marginBottom:10}}>Mídias Diárias (6h)</div>
            <table style={s.table}>
              <thead><tr>
                {['Mídia','Especificação','1 dia','2-6 dias/dia','7+ dias/dia','Ação'].map(h=><th key={h} style={s.th}>{h}</th>)}
              </tr></thead>
              <tbody>
                {precosPorTipo.diaria.map(p => (
                  <tr key={p.id}>
                    <td style={{...s.td,fontWeight:700}}>{p.midia_nome}</td>
                    <td style={{...s.td,fontSize:11,color:C.muted}}>{p.unidade}</td>
                    {editandoPreco === p.id ? (
                      <>
                        <td style={s.td}><input style={{...s.input,width:110}} type="number" value={((precosEdit[p.id]||{}).preco_1)||''} onChange={e=>setPrecosEdit(prev=>({...prev,[p.id]:{...prev[p.id],preco_1:e.target.value}})}/></td>
                        <td style={s.td}><input style={{...s.input,width:110}} type="number" value={((precosEdit[p.id]||{}).preco_2_6)||''} onChange={e=>setPrecosEdit(prev=>({...prev,[p.id]:{...prev[p.id],preco_2_6:e.target.value}})}/></td>
                        <td style={s.td}><input style={{...s.input,width:110}} type="number" value={((precosEdit[p.id]||{}).preco_7mais)||''} onChange={e=>setPrecosEdit(prev=>({...prev,[p.id]:{...prev[p.id],preco_7mais:e.target.value}})}/></td>
                        <td style={s.td}>
                          <Btn onClick={()=>salvarPreco(p.id)} style={{fontSize:11,padding:'4px 10px',marginRight:4}}>Salvar</Btn>
                          <Btn variant="ghost" onClick={()=>setEditandoPreco(null)} style={{fontSize:11,padding:'4px 10px'}}>Cancelar</Btn>
                        </td>
                      </>
                    ) : (
                      <>
                        <td style={{...s.td,fontWeight:700,color:C.accent}}>{fmtR(p.preco_1)}</td>
                        <td style={{...s.td,color:'#16a34a',fontWeight:600}}>{fmtR(p.preco_2_6)}</td>
                        <td style={{...s.td,color:'#16a34a',fontWeight:600}}>{fmtR(p.preco_7mais)}</td>
                        <td style={s.td}><Btn variant="ghost" onClick={()=>{ setEditandoPreco(p.id); setPrecosEdit(prev=>({...prev,[p.id]:{preco_1:p.preco_1,preco_2_6:p.preco_2_6,preco_7mais:p.preco_7mais,desconto_multi:p.desconto_multi,desconto_6h:p.desconto_6h,unidade:p.unidade}})); }} style={{fontSize:11,padding:'4px 10px'}}>✏️ Editar</Btn></td>
                      </>
                    )}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {/* PACOTE 30 DIAS */}
          <div style={{marginBottom:20}}>
            <div style={{fontSize:11,fontWeight:700,color:C.muted,textTransform:'uppercase',letterSpacing:'0.06em',marginBottom:10}}>Pacotes 30 Dias</div>
            <table style={s.table}>
              <thead><tr>
                {['Mídia','Especificação','Preço (30 dias)','Desconto 2+ períodos (%)','Ação'].map(h=><th key={h} style={s.th}>{h}</th>)}
              </tr></thead>
              <tbody>
                {precosPorTipo.pacote30.map(p => (
                  <tr key={p.id}>
                    <td style={{...s.td,fontWeight:700}}>{p.midia_nome}</td>
                    <td style={{...s.td,fontSize:11,color:C.muted}}>{p.unidade}</td>
                    {editandoPreco === p.id ? (
                      <>
                        <td style={s.td}><input style={{...s.input,width:130}} type="number" value={((precosEdit[p.id]||{}).preco_1)||''} onChange={e=>setPrecosEdit(prev=>({...prev,[p.id]:{...prev[p.id],preco_1:e.target.value}}))/></td>
                        <td style={s.td}><input style={{...s.input,width:80}} type="number" value={((precosEdit[p.id]||{}).desconto_multi)||''} onChange={e=>setPrecosEdit(prev=>({...prev,[p.id]:{...prev[p.id],desconto_multi:e.target.value}}))/></td>
                        <td style={s.td}>
                          <Btn onClick={()=>salvarPreco(p.id)} style={{fontSize:11,padding:'4px 10px',marginRight:4}}>Salvar</Btn>
                          <Btn variant="ghost" onClick={()=>setEditandoPreco(null)} style={{fontSize:11,padding:'4px 10px'}}>Cancelar</Btn>
                        </td>
                      </>
                    ) : (
                      <>
                        <td style={{...s.td,fontWeight:700,color:C.accent}}>{fmtR(p.preco_1)}</td>
                        <td style={{...s.td,color:'#16a34a',fontWeight:600}}>{p.desconto_multi}%</td>
                        <td style={s.td}><Btn variant="ghost" onClick={()=>{ setEditandoPreco(p.id); setPrecosEdit(prev=>({...prev,[p.id]:{preco_1:p.preco_1,preco_2_6:p.preco_2_6,preco_7mais:p.preco_7mais,desconto_multi:p.desconto_multi,desconto_6h:p.desconto_6h,unidade:p.unidade}})); }} style={{fontSize:11,padding:'4px 10px'}}>✏️ Editar</Btn></td>
                      </>
                    )}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {/* POR HORA */}
          <div>
            <div style={{fontSize:11,fontWeight:700,color:C.muted,textTransform:'uppercase',letterSpacing:'0.06em',marginBottom:10}}>Por Hora</div>
            <table style={s.table}>
              <thead><tr>
                {['Mídia','Especificação','Preço/hora','Desconto pacote 6h (%)','Ação'].map(h=><th key={h} style={s.th}>{h}</th>)}
              </tr></thead>
              <tbody>
                {precosPorTipo.hora.map(p => (
                  <tr key={p.id}>
                    <td style={{...s.td,fontWeight:700}}>{p.midia_nome}</td>
                    <td style={{...s.td,fontSize:11,color:C.muted}}>{p.unidade}</td>
                    {editandoPreco === p.id ? (
                      <>
                        <td style={s.td}><input style={{...s.input,width:110}} type="number" value={((precosEdit[p.id]||{}).preco_1)||''} onChange={e=>setPrecosEdit(prev=>({...prev,[p.id]:{...prev[p.id],preco_1:e.target.value}}))/></td>
                        <td style={s.td}><input style={{...s.input,width:80}} type="number" value={((precosEdit[p.id]||{}).desconto_6h)||''} onChange={e=>setPrecosEdit(prev=>({...prev,[p.id]:{...prev[p.id],desconto_6h:e.target.value}}))/></td>
                        <td style={s.td}>
                          <Btn onClick={()=>salvarPreco(p.id)} style={{fontSize:11,padding:'4px 10px',marginRight:4}}>Salvar</Btn>
                          <Btn variant="ghost" onClick={()=>setEditandoPreco(null)} style={{fontSize:11,padding:'4px 10px'}}>Cancelar</Btn>
                        </td>
                      </>
                    ) : (
                      <>
                        <td style={{...s.td,fontWeight:700,color:C.accent}}>{fmtR(p.preco_1)}</td>
                        <td style={{...s.td,color:'#16a34a',fontWeight:600}}>{p.desconto_6h}%</td>
                        <td style={s.td}><Btn variant="ghost" onClick={()=>{ setEditandoPreco(p.id); setPrecosEdit(prev=>({...prev,[p.id]:{preco_1:p.preco_1,preco_2_6:p.preco_2_6,preco_7mais:p.preco_7mais,desconto_multi:p.desconto_multi,desconto_6h:p.desconto_6h,unidade:p.unidade}})); }} style={{fontSize:11,padding:'4px 10px'}}>✏️ Editar</Btn></td>
                      </>
                    )}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* FORMULÁRIO NOVA PROPOSTA */}
      {showForm && (
        <div style={{...s.card,marginBottom:20}}>
          <h3 style={{fontSize:14,fontWeight:700,marginBottom:16,color:C.accent}}>Nova Proposta</h3>
          <div style={s.grid2}>
            <div style={{marginBottom:12}}>
              <label style={s.label}>Cliente *</label>
              <select style={s.select} value={form.cliente_id} onChange={e=>setForm(p=>({...p,cliente_id:e.target.value}))}>
                <option value="">Selecione...</option>
                {clientes.map(c=><option key={c.id} value={c.id}>{c.empresa}</option>)}
              </select>
            </div>
            <Input label="Título da Campanha *" value={form.titulo} onChange={v=>setForm(p=>({...p,titulo:v}))}/>
            <Input label="Período Início" value={form.periodo_inicio} onChange={v=>setForm(p=>({...p,periodo_inicio:v}))} type="date"/>
            <Input label="Período Fim" value={form.periodo_fim} onChange={v=>setForm(p=>({...p,periodo_fim:v}))} type="date"/>
            <Input label="CNPJ" value={form.cnpj} onChange={v=>setForm(p=>({...p,cnpj:v}))} placeholder="00.000.000/0001-00"/>
            <Input label="Agência" value={form.agencia} onChange={v=>setForm(p=>({...p,agencia:v}))} placeholder="Nome da agência (opcional)"/>
          </div>

          {/* ADICIONAR MÍDIAS */}
          <div style={{background:'#f8fafc',border:'1px solid '+C.border,borderRadius:12,padding:16,marginBottom:16}}>
            <div style={{fontSize:13,fontWeight:700,color:C.accent,marginBottom:12}}>Adicionar Mídia</div>
            <div style={{display:'grid',gridTemplateColumns:'2fr 1fr 1fr auto',gap:10,alignItems:'end'}}>
              <div>
                <label style={s.label}>Mídia</label>
                <select style={s.select} value={midiaAdd.precoId} onChange={e=>setMidiaAdd(p=>({...p,precoId:e.target.value,quantidade:1,precoCustom:''}))}>
                  <option value="">Selecione a mídia...</option>
                  <optgroup label="── Diárias (6h) ──">
                    {precosPorTipo.diaria.map(p=><option key={p.id} value={p.id}>{p.midia_nome}</option>)}
                  </optgroup>
                  <optgroup label="── Pacote 30 dias ──">
                    {precosPorTipo.pacote30.map(p=><option key={p.id} value={p.id}>{p.midia_nome}</option>)}
                  </optgroup>
                  <optgroup label="── Por Hora ──">
                    {precosPorTipo.hora.map(p=><option key={p.id} value={p.id}>{p.midia_nome}</option>)}
                  </optgroup>
                </select>
              </div>
              <div>
                <label style={s.label}>{midiaAdd.precoId ? labelQuantidade((precos.find(function(p){return p.id===midiaAdd.precoId;})||{}).tipo) : 'Quantidade'}</label>
                <input style={s.input} type="number" min="1" value={midiaAdd.quantidade} onChange={e=>setMidiaAdd(p=>({...p,quantidade:e.target.value,precoCustom:''}))}/>
              </div>
              <div>
                <label style={s.label}>Valor Total (opcional)</label>
                <input style={s.input} type="text" value={midiaAdd.precoCustom} onChange={e=>setMidiaAdd(p=>({...p,precoCustom:e.target.value}))} placeholder={midiaAdd.precoId ? fmtR(calcularPreco(precos.find(p=>p.id===midiaAdd.precoId), midiaAdd.quantidade)) : 'Auto'}/>
              </div>
              <Btn onClick={adicionarMidia} style={{whiteSpace:'nowrap'}}>+ Adicionar</Btn>
            </div>

            {/* Preview do preço calculado */}
            {midiaAdd.precoId && (
              <div style={{marginTop:10,padding:'8px 12px',background:'#eff6ff',borderRadius:8,fontSize:12,color:'#1565c0'}}>
                {(() => {
                  const p = precos.find(x=>x.id===midiaAdd.precoId);
                  if (!p) return null;
                  const total = calcularPreco(p, midiaAdd.quantidade);
                  return (
                    <span>
                      <strong>{p.midia_nome}</strong> — {p.unidade} — {precoUnitLabel(p, midiaAdd.quantidade)}
                      {' → '}
                      <strong style={{color:'#1a237e'}}>Total: {fmtR(total)}</strong>
                      {midiaAdd.precoCustom && <span style={{color:'#f59e0b',marginLeft:8}}>(valor personalizado: {fmtR(parseFloat(midiaAdd.precoCustom.replace(',','.'))||0)})</span>}
                    </span>
                  );
                })()}
              </div>
            )}
          </div>

          {/* MÍDIAS SELECIONADAS */}
          {form.midias_selecionadas.length > 0 && (
            <div style={{marginBottom:16}}>
              <div style={{fontSize:12,fontWeight:700,color:C.muted,textTransform:'uppercase',letterSpacing:'0.05em',marginBottom:10}}>Mídias da Proposta</div>
              <table style={s.table}>
                <thead><tr>
                  {['Mídia','Especificação','Qtd','Detalhes de Preço','Valor Total',''].map(h=><th key={h} style={s.th}>{h}</th>)}
                </tr></thead>
                <tbody>
                  {form.midias_selecionadas.map((m,idx) => (
                    <tr key={idx}>
                      <td style={{...s.td,fontWeight:700}}>{m.midia_nome}</td>
                      <td style={{...s.td,fontSize:11,color:C.muted}}>{m.unidade}</td>
                      <td style={{...s.td,textAlign:'center'}}>{m.quantidade}</td>
                      <td style={{...s.td,fontSize:11,color:C.muted}}>{m.label_unit}</td>
                      <td style={s.td}>
                        <div style={{display:'flex',alignItems:'center',gap:6}}>
                          <input
                            style={{...s.input,width:130,fontWeight:700,color:C.accent}}
                            type="text"
                            value={m.preco_total.toLocaleString('pt-BR',{minimumFractionDigits:2})}
                            onChange={e=>editarPrecoMidia(idx, e.target.value)}
                          />
                          {m.editado && <span style={{fontSize:10,color:'#f59e0b',whiteSpace:'nowrap'}}>✏️ editado</span>}
                          {!m.editado && m.preco_auto !== m.preco_total && <span style={{fontSize:10,color:'#16a34a',whiteSpace:'nowrap'}}>desc. aplicado</span>}
                        </div>
                      </td>
                      <td style={s.td}>
                        <button onClick={()=>removerMidia(idx)} style={{background:'none',border:'none',cursor:'pointer',color:C.danger,fontSize:16,fontWeight:700}}>✕</button>
                      </td>
                    </tr>
                  ))}
                  <tr>
                    <td colSpan={4} style={{...s.td,textAlign:'right',fontWeight:700,fontSize:13}}>TOTAL DA PROPOSTA</td>
                    <td style={{...s.td,fontWeight:800,fontSize:16,color:C.accent}}>{fmtR(totalProposta)}</td>
                    <td style={s.td}></td>
                  </tr>
                </tbody>
              </table>
            </div>
          )}

          <div style={{marginBottom:12}}>
            <label style={s.label}>Observações</label>
            <textarea style={{...s.input,height:64,resize:'vertical'}} value={form.observacoes} onChange={e=>setForm(p=>({...p,observacoes:e.target.value}))}/>
          </div>

          <div style={{display:'flex',gap:8,alignItems:'center'}}>
            <Btn onClick={salvar}>Salvar Proposta</Btn>
            <Btn variant="ghost" onClick={()=>setShowForm(false)}>Cancelar</Btn>
            {totalProposta > 0 && <span style={{fontSize:13,color:C.muted,marginLeft:8}}>Total: <strong style={{color:C.accent}}>{fmtR(totalProposta)}</strong></span>}
          </div>
        </div>
      )}

      {/* LISTA DE PROPOSTAS */}
      <div style={s.card}>
        <table style={s.table}>
          <thead><tr>{['Nº','Cliente','Campanha','Período','Mídias','Valor','Status','Ações'].map(h=><th key={h} style={s.th}>{h}</th>)}</tr></thead>
          <tbody>
            {propostas.map(p=>(
              <tr key={p.id}>
                <td style={{...s.td,fontFamily:'monospace',color:C.muted,fontSize:11}}>{p.numero}</td>
                <td style={s.td}>{p.cliente_nome}</td>
                <td style={{...s.td,fontWeight:600}}>{p.titulo}</td>
                <td style={{...s.td,fontSize:12,color:C.muted}}>{p.periodo_inicio ? new Date(p.periodo_inicio).toLocaleDateString('pt-BR') : '—'}</td>
                <td style={s.td}>
                  <div style={{display:'flex',flexWrap:'wrap',gap:4}}>
                    {(p.midias||[]).slice(0,3).map((m,i)=>(
                      <span key={i} style={{...s.badge(C.accent),fontSize:10}}>{m.nome||m}</span>
                    ))}
                    {(p.midias||[]).length > 3 && <span style={{fontSize:10,color:C.muted}}>+{(p.midias||[]).length-3}</span>}
                  </div>
                </td>
                <td style={{...s.td,fontWeight:700,color:C.gold}}>{fmtN(p.valor)}</td>
                <td style={s.td}><Badge status={p.status}/></td>
                <td style={s.td}>
                  <div style={{display:'flex',gap:4,flexWrap:'wrap'}}>
                    <Btn onClick={()=>gerarPDFProposta(p)} style={{fontSize:10,padding:'3px 8px',background:'#6366f1'}}>PDF</Btn>
                    {p.status==='Rascunho'&&<Btn onClick={()=>mudarStatus(p.id,'Enviada')} style={{fontSize:10,padding:'3px 8px',background:C.warning}}>Enviar</Btn>}
                    {(p.status==='Enviada'||p.status==='Rascunho')&&<Btn onClick={()=>aprovar(p.id)} style={{fontSize:10,padding:'3px 8px'}}>✓ Aprovar</Btn>}
                    {p.status==='Enviada'&&<Btn onClick={()=>mudarStatus(p.id,'Reprovada')} style={{fontSize:10,padding:'3px 8px',background:C.danger}}>Reprovar</Btn>}
                    {p.status==='Aprovada'&&<Btn onClick={()=>gerarPDFFinanceiro(p, null, clientes.find(c=>c.id===p.cliente_id))} style={{fontSize:10,padding:'3px 8px',background:'#e63946'}}>Doc Fin.</Btn>}
                  </div>
                </td>
              </tr>
            ))}
            {propostas.length===0&&<tr><td colSpan={8} style={{...s.td,textAlign:'center',color:C.muted,padding:32}}>Nenhuma proposta cadastrada.</td></tr>}
          </tbody>
        </table>
      </div>
    </div>
  );
}
