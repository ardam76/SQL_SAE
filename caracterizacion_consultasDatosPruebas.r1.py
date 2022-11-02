# -*- coding: utf-8 -*-
"""
Created on Wed Oct 19 11:52:40 2022

@author: antonio.rodriguez.de

Este programa genera las consultas necesarias para extraer identificadores de
    pruebas para el desarrollo de Caracterizaciónd e citas
    
La SQL resultante debe lanzarse sobre el esquema PREXOD, con visibilidad tanto
    hacia HERMES pre como a GU pre.
    
Leyenda:
-- D1: Existe la demanda local en A renovable
-- D2: Existe la demanda local en B no recuperable
-- D3: Existe la demanda local en B recuperable
-- D4: Existe la demanda local en S con intermediación
-- D5: Existe demanda trasladada
-- D6: Existe la demanda local en A no-renovable
-- D7: Existe la demanda local en S sin intermediación

-- E1: Es persona extranjera y tiene autorizacion caducada
-- E2: Es persona extranjera y tiene autorizacion NO caducada
-- E3: No es persona extranjera

-- U1: Existe usuario en CAS no validado
-- U2: Existe usuario en CAS validado
-- U3: No Existe usuario en CAS

-- C1: Ha tenido cita previa alguna vez
-- C2: No ha tenido cita previa nunca

-- L1: Es de oficina pilotada
-- L2: Es de oficina no pilotada

"""

""" sql
Consulta para extracción de resultados:
    
select 
    substr(per_txt,1,1) tip_nif, 
    substr(per_txt,2,8) num_nif, 
    substr(per_txt,10,1) let_nif,
    per_txt2 leyenda
from pcod_tmp2@sicasrep 
where usuario = 'ARDAM'
order by 4
"""

clear_delete = 'delete from pcod_tmp2@sicasrep where usuario = \'ARDAM\';'
pilotada = 'define PILOTADA = (\'04638\',\'04639\',\'04640\',\'04630\',\'04280\',\'04620\',\'04610\',\'04600\',\'04288\',\'04628\',\'04740\',\'04741\',\'04745\',\'04730\',\'04738\',\'04729\',\'04728\',\'04727\',\'04721\',\'04720\',\'11639\',\'11620\',\'11630\',\'11638\',\'11540\',\'11612\',\'11611\',\'11600\',\'11610\',\'11679\',\'14080\',\'14610\',\'14003\',\'14007\',\'14350\',\'14320\',\'14310\',\'14300\',\'14210\',\'14008\',\'14002\',\'14001\',\'14547\',\'14549\',\'14546\',\'14500\',\'18698\',\'18699\',\'18697\',\'18690\',\'18328\',\'18329\',\'18330\',\'18339\',\'18101\',\'18327\',\'18320\',\'18102\',\'18340\',\'21810\',\'21819\',\'21001\',\'21003\',\'21004\',\'21006\',\'21007\',\'21100\',\'21110\',\'21120\',\'21122\',\'21130\',\'21459\',\'21080\',\'21580\',\'21310\',\'21319\',\'21320\',\'21309\',\'21300\',\'21600\',\'21647\',\'23690\',\'23685\',\'23692\',\'23693\',\'23691\',\'23686\',\'23687\',\'23688\',\'23689\',\'23670\',\'23684\',\'23680\',\'23770\',\'23746\',\'23747\',\'23748\',\'23749\',\'23750\',\'23740\',\'23760\',\'29330\',\'29328\',\'29327\',\'29320\',\'29395\',\'29340\',\'29692\',\'29691\',\'29690\',\'29680\',\'29689\',\'29688\',\'29003\',\'29004\',\'41350\',\'41320\',\'41318\',\'41703\',\'41700\',\'41702\',\'41701\',\'41704\',\'41089\',\'41728\',\'41727\',\'41720\',\'41006\');'
commit = 'commit;'

cabecera = clear_delete+'\n'+commit+'\n'+pilotada+'\n'

############### Condiciones de demanda ###############

# D1: Existe la demanda local en A renovable
D1 = 'g.sit_adm_cod = \'A\' and g.ccaa_dem_est in (\'C\',\'G\',\'I\') and'
D1 += ' g.dem_fec_pre_ren > sysdate-2 and'
# D2: Existe la demanda local en B no recuperable
D2 = 'g.sit_adm_cod = \'B\' and g.ccaa_dem_est in (\'C\',\'G\',\'I\') and'
D2 += ' g.dem_fec_cau_sit_adm < sysdate - 10000 and'
# D3: Existe la demanda local en B recuperable
D3 = 'g.sit_adm_cod = \'B\' and g.ccaa_dem_est in (\'C\',\'G\',\'I\') and '
D3 += 'g.dem_fec_cau_sit_adm > sysdate - 600 and'
# D4: Existe la demanda local en S con intermediación
D4 = 'g.sit_adm_cod = \'S\' and g.ccaa_dem_est in (\'C\',\'G\',\'I\') and'
D4 += ' g.cau_cod > 500 and'
# D5: Existe demanda trasladada
D5 = 'g.sit_adm_cod = \'A\' and g.ccaa_dem_est = (\'T\') and'
# D6: Existe la demanda local en A no-renovable
D6 = 'g.sit_adm_cod = \'A\' and g.ccaa_dem_est in (\'C\',\'G\',\'I\') and'
D6 += ' g.dem_fec_pre_ren < sysdate-15 and'
# D7: Existe la demanda local en S sin intermediación
D7 = 'g.sit_adm_cod = \'S\' and g.ccaa_dem_est in (\'C\',\'G\',\'I\') and'
D7 += ' g.cau_cod < 500 and'

D = [D1,D2,D3,D4,D5,D6,D7]

############### Condiciones de extranjeros ###############

# E1: Es persona extranjera y tiene autorizacion caducada
E1 = 'p.per_tip_doc = \'E\' and p.ccaa_per_prm_tra_fec < sysdate and'
# E2: Es persona extranjera y tiene autorizacion NO caducada
E2 = 'p.per_tip_doc = \'E\' and p.ccaa_per_prm_tra_fec > sysdate and'
# E3: No es persona extranjera
E3 = 'p.per_tip_doc = \'D\' and'

E = [E1,E2,E3]

############### Condiciones de Gestión de Usuarios ###############

from_U = '(select p1.per_cod , gu.gu_num, gu.gu_let, gu.l_validado from ' 
from_U += '(select per_cod, per_num_doc, per_let_doc, per_fec_nac from si_pers) p1' 
from_U += ' left outer join (select substr(c_nif,1,8) gu_num, '
from_U += 'substr(c_nif,9,1) gu_let, f_nacimiento fec_nac, l_validado from '
from_U += 'ges_usuarios.gu_ciudadanos@preove_replica) gu '
from_U += 'on p1.per_num_doc = gu.gu_num and p1.per_let_doc = gu.gu_let'
from_U += ' and nvl(p1.per_fec_nac,sysdate) = nvl(gu.fec_nac,sysdate)) pgu'

# U1: Existe usuario en CAS no validado
U1 = 'p.per_cod = pgu.per_cod and pgu.gu_num is not null and l_validado = \'N\' and'
# U2: Existe usuario en CAS validado
U2 = 'p.per_cod = pgu.per_cod and pgu.gu_num is not null and l_validado = \'S\' and'
# U3: No Existe usuario en CAS
U3 = 'p.per_cod = pgu.per_cod and pgu.gu_num is null and'

U = [U1,U2,U3]

############### Condiciones de Cita Previa ###############

from_C = '(select p1.per_cod , c.c_num, c.c_let  from ' 
from_C += '(select per_cod, per_num_doc, per_let_doc from si_pers) p1' 
from_C += ' left outer join (select substr(nif,1,8) c_num, '
from_C += 'substr(nif,9,1) c_let from '
from_C += 'ruby.personal_datas@citapro_obs) c '
from_C += 'on p1.per_num_doc = c.c_num and p1.per_let_doc = c.c_let) pcit' 
    ## Control fecha nacimiento

# C1: Ha tenido cita previa alguna vez
C1 = 'p.per_cod = pcit.per_cod and pcit.c_num is not null and '

# C2: No ha tenido cita previa nunca
C2 = 'p.per_cod = pcit.per_cod and pcit.c_num is null and '

C = [C1, C2]

############### Condiciones de Pilotaje ###############

# L1: Es de oficina pilotada
L1 = 'p.cps_res_cod in &PILOTADA and'
# L2: Es de oficina no pilotada
L2 = 'p.cps_res_cod not in &PILOTADA and'

L = [L1,L2]

countd = counte = countu = countl = countc = 0
out_select = cabecera+'\n'

insert_1 = 'insert into pcod_tmp2@sicasrep select p.per_cod,'
insert_1+= ' p.per_tip_doc||p.per_num_doc||p.per_let_doc, null,\'ARDAM\', null,'
from_1 = 'from si_pers@sicasrep p, si_dema_g1@sicasrep g'
from_total = from_1+',\n'+from_U+',\n'+from_C
where_end = ' p.per_cod not in (select per_cod from pcod_tmp2@sicasrep where usuario = \'ARDAM\') and rownum <= 20;'

for d in D:
    countd += 1
    counte = countu = countl = countc = 0
    for e in E:
        counte +=1
        countu = countl = countc = 0
        for u in U:
            countu+=1
            countl = countc = 0
            for c in C:
                countc+=1
                countl = 0
                for l in L:
                    countl +=1
                    cabeza2 = '\''+'D'+str(countd)+'E'+str(counte)+'U'+str(countu)+'C'+str(countc)+'L'+str(countl)+'\''
                    where_s = 'where p.per_cod = g.per_cod and'+' '+d+' '+e+' '+u+' '+' '+c+' '+l+where_end
                    out_select += insert_1+'\n'+cabeza2+'\n'+from_total+'\n'+where_s+'\n'+commit+'\n'
                

file = open("consulta_datos_pruebas.r1.sql","w")
file.write(out_select)
file.close()