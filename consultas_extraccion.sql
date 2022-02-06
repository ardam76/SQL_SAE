/* UPO.DOC 
	Antonio Rodríguez Delgado. 2022.
*/

/*Consultas para extracciones iniciales*/
/*
	Acrónimos para la estructura de tablas:

	VAL -> Tablas de valores maestros.
	DAT -> Tablas de datos o registros "vivos".
	HIS -> Tablas con datos en series históricas.
*/

--- Persona física. Tabla DAT_PERS ---

select p.* from 
	(select 
		per_cod, 
		pai_cod, -- Código de país
		trunc(per_fec_nac,'MONTH') mes_nacimiento, 
		floor(months_between(sysdate,per_Fec_nac)/12) as edad_ext,
		sex_cod, 
		decode(niv_aca_cod,'90','00','80','01','32','33','33','32',niv_aca_cod) niv_aca_cod, 
		mun_res_cod, 
		cps_res_cod, 
		substr(mun_res_cod, 1,2) as prov_res_cod,
		decode(per_cor_ele,null, 'N','S') tiene_mail,
		decode(per_tlf_con,null,'N','S') tiene_t1,
		decode(ccaa_per_tlf_con_2,null,'N','S') teiene_t2,
		decode(ccaa_per_tlf_con_3,null,'N','S') tiene_t3,
		decode(per_tlf_con_4,null,'N','S') tiene_t4,
		decode(substr(nvl(per_tlf_con,0),1,1),'6','S','7','S',
			decode(substr(nvl(ccaa_per_tlf_con_2,0),1,1),'6','S','7','S',
			decode(substr(nvl(ccaa_per_tlf_con_3,0),1,1),'6','S','7','S',
			decode(substr(nvl(per_tlf_con_4,0),1,1),'6','S','7','S','N')))) tiene_movil,
		DECODE(per_gra_min,null,'N','S') tiene_disc  
	from si_pers
	where
		substr(mun_res_cod, 1, 2) in ('04', '11', '14','18','21','23','29','41')) p
LEFT OUTER JOIN
	(select per_cod from si_pers_cond_esp where cond_esp_val = '01') v
ON p.per_cod = v.per_cod
where v.per_cod is null


/*Decisiones sobre la extracción inicial de datos de Persona Física:
	
	PER_COD es la clave primaria de la entidad
	
	PAI_COD es el código de país de nacimiento:
		La tabla mestra origen es la codificada en el SAE como TBXCPAIS.
		En el modelo propio adquiere el valor VAL_PAIS
			-- select p.pai_cod, p.pai_des, decode(c.val_val,null, 'N', 'S') es_UE
				from
					(select val_val pai_cod, val_des pai_des from VW_GEOG_PAIS_INT) p
				left outer join
					(select val_val from VW_GEOG_PAIS_CEE_INT) c
				on p.pai_cod = c.val_val
				order by 1
			Se extrae la tabla con indicadores sobre si el país es o no perteneciente a la Unión Europea
			ya que se considera que es un dato que puede ser relevante para las oportunidades de empleo.
	MES_NACIMIENTO es el mes y el año de nacimiento. Se filtra el día para aumentar el grado de anonimización.
	EDAD_EXT es el valor numérico de la edad en el momento de la extracción.
	SEX_COD es el código de sexo:
		La tabla mestra origen es la codificada en el SAE como TCMCSEXO:
			1	HOMBRE
			2	MUJER
				-- select val_val cod_sexo, val_des des_sexo 
					from vw_valores_int 
					where def_cod = 'TCMCSEXO'
		En el modelo propio adquiere el valor VAL_SEXO.
		En el momento de la extracción no hay valores disponibles en otra tabla diferentes de HOMBRE o MUJER.
	NIV_ACA_COD es el nivel académico máximo alcanzado.
		La tabla mestra origen es la codificada en el SAE como VW_NIVE_PROF_INT
			-- select 
				decode(val_val,'90','00','80','01','32','33','33','32', val_val) niv_cod, 
				val_Des niv_des 
				from VW_NIVE_PROF_INT order by 1
		Decisiones adoptadas por consulta con personal experto para alinear numéricamente los niveles:
			- El nivel 99 se asimila al menor posible, 00.
			- El nivel 80 se asimila al 01.
			- Los niveles 32 y 33, están invertidos por un error en la tabla maestra original.
		En el modelo propio adquiere el valor VAL_NIV_ACA
	MUN_RES_COD es el código de municipio de residencia
		La tabla mestra origen es la codificada en el SAE como VAL_GEOG_MUNI_VAL
		En el modelo propio adquiere el valor VAL_MUNI
		Se filtran los municipios de Andalucía, pues de los residentes en otras CAs no hay datos administrativos
		accesibles, y por tanto no tienen valor analítico.
		-- select val_val mun_cod, val_Des mun_des from val_geog_muni_val
			where
			substr(val_val, 1, 2) in ('04', '11', '14','18','21','23','29','41')
			order by 1
	CPS_RES_COD es el código postal de residencia.
		La tabla maestra orign es la codificada en SAE como VAL_GEOG_CDPO
		En el modelo propio adquiere el valor VAL_CDPO
		Se filtran igual que en el caso anterior, los códigos postales de Andalucía, por el mismo motivo.
		-- select val_val cdpo_cod from val_geog_CDPO
			where
			substr(val_val, 1, 2) in ('04', '11', '14','18','21','23','29','41')
			order by 1
	PROV_RES_COD es el código de provincia. Realmente es un filtrado de la subcadena (1,2) del código de municipio.
		La tabla maestra origen es la codificada en SAE como VAL_GEOG_PROV_VAL.
		En el modelo propio adquiere el valor VAL_PROV
		-- select val_val prv_cod, val_des prv_des 
			from val_geog_prov_val 
			where val_val in ('04', '11', '14','18','21','23','29','41')
	TIENE_MAIL es un campo cateogrizado. Se toma el capo de origen con el correo electrónico de la persona y
		si es distinto de nulo se carga con el valor 'S', y con ekl valor 'N' en caso contrario.
	TIENE_T1, TIENE_T2, TIENE_T3 y TIENE_T4 tiene el mismo funcionamiento que el campo anterior, pero con respecto
		a los 4 campos de teléfono que están disponibles en el registro original.
	TIENE_MOVIL es un procesado de los 4 campos de teléfono y carga con el valor 'S' el dato si alguno de los
		teléfonos informados comienza por 6 o por 7. Cargará una N en caso contrario.
	TIENE_DISC es un procesado del campo de grado de discapacidad que carga un valor 'S' si la persona tiene +
		declarado algún grado de discapacidad.

	Se han excluido de forma intencionada todos los datos persona

*/

--- Demanda. Tabla DAT_DEMANDA ---

select D.* from 
	(SELECT 
	PER_COD,

	/*DATOS ADMINISTRATIVOS*/
	DEM_FEC_INS,
	DECODE(SIT_ADM_COD, 'B', FLOOR(DEM_FEC_INI_SIT_ADM - DEM_FEC_INS),
		FLOOR(SYSDATE - DEM_FEC_INS)) DIAS_ULT_INSCR,
	SIT_ADM_COD, DEM_FEC_INI_SIT_ADM,
	CAU_COD, DEM_FEC_CAU_SIT_ADM,
	DECODE(SIT_ADM_COD,'B','00',SIT_LAB_COD) SIT_LAB_COD, 
    DECODE(SIT_ADM_COD,'B',DEM_FEC_INI_SIT_ADM,DEM_FEC_INI_SIT_LAB) DEM_FEC_INI_SIT_LAB,
	decode(niv_aca_cod,'90','00','80','01','32','33','33','32',niv_aca_cod) niv_aca_cod, -- NIVEL FORM. INTERMEDIACION
	ACTI_ECO_COD,
 	DECODE(SIT_ADM_COD, 'B', 'N',
	    CASE WHEN NVL(DEM_FEC_INI_PRE,SYSDATE+1)<SYSDATE THEN 
		    CASE WHEN NVL(DEM_FEC_FIN_PRE,SYSDATE+1)>SYSDATE THEN 'S' 
		    ELSE 'N' END
		ELSE 'N' END) AS TIENE_PREST,
	DEM_FEC_INI_PRE, DEM_FEC_FIN_PRE, 
	DECODE(SIT_ADM_COD, 'B', 0,
		CASE WHEN NVL(DEM_FEC_FIN_PRE,SYSDATE-1)<SYSDATE THEN 0 ELSE
    		DECODE(DEM_FEC_FIN_PRE-DEM_FEC_INI_PRE,NULL,0,DEM_fEC_FIN_PRE-DEM_FEC_INI_PRE)
    	END) DUR_PRES,
	NVL(CCAA_DEM_FEC_UMDC,DEM_fEC_INS) CCAA_DEM_FEC_UMDC,
	DECODE(SIT_ADM_COD, 'B', FLOOR(DEM_FEC_INI_SIT_ADM - NVL(CCAA_DEM_FEC_UMDC,DEM_fEC_INS)),
		FLOOR(SYSDATE - NVL(CCAA_DEM_FEC_UMDC,DEM_fEC_INS))) DIAS_SINCAMBIO,
	CCAA_DEM_FEC_ULT, --------- FECHA DE ULTIMA PARTICIPACIÓN EN OFERTA
	DECODE(SIT_ADM_COD, 'B', FLOOR(DEM_FEC_INI_SIT_ADM - NVL(CCAA_DEM_FEC_ULT,DEM_FEC_INS)),
		FLOOR(SYSDATE - NVL(CCAA_DEM_FEC_ULT,DEM_FEC_INS))) DIAS_SINOFERTA,

	/* PREFERENCIAS */
	JOR_COD, ------------------ JORNADA SOLICITADA
	DEM_DIS_DOM, -------------- DISPONIBILIDAD PARA TRABAJO A DOMICILIO
	DEM_DIS_AUT_EMP, ---------- DISPONIBILIDAD APRA AUTOEMPLEO
	DEM_DIS_TEL, -------------- DISPONIBILDIAD PARA TELETRABAJO
	DEM_DIS_ETT,
	DEM_TUR_NOC,
	DEM_TUR_FIE,
	DIS_VIA_COD, -------------- DISPONIBILIDAD PARA VIAJAR
	AMB_BUS_EMP_COD
from
	SI_DEMA_G1
where
	CCAA_DEM_EST IN ('C','G','I') AND 
	DECODE(JOR_COD, ' ', '99',JOR_COD) < '99') D
LEFT OUTER JOIN
	(select per_cod from si_pers_cond_esp where cond_esp_val = '01') v
ON D.per_cod = v.per_cod
where v.per_cod is null

/*Decisiones sobre la extracción inicial de datos de DEMANDA:

	Descripción: Hay varias tablas de demanda dem empleo, pero todas ellas convergen en un registro 
	principal que es SI_DEMA_G1 sobre la que nos centraremos ahora. Se relaciona con SI_PERS 
	en 1 a 1, y recoge la situación administrativa y laboral puntual de la persona en el momento de 
	la extracción, así como algunos datos de preferencias.

	PER_COD es la clave primaria de la entidad, y mediante la que podemos relacionar cada registro con
	su contrapartida en SI_PERS.

	--> Datos administrativos:
		DEM_FEC_INS recoge la fecah de inscripción

		DIAS_ULT_INSCR recoge el número de días trasncurridoS en el último periodo de inscripción como
			demandante de empleo. Se extrae mendiante la cláusula:
			DECODE(SIT_ADM_COD, 'B', FLOOR(DEM_FEC_INI_SIT_ADM - DEM_FEC_INS,
					FLOOR(SYSDATE - DEM_FEC_INS) DIAS_ULT_INSCR

		SIT_ADM_COD recoge la situación admisnitrativa según se codifica en VAL_SITADM
			select val_val sit_cod, val_Des sit_des from VW_SITA_ADMI_DEMA_INT

			B	BAJA 		--> La demanda no está en búsqueda de empleo
			S	SUSPENSIÓN 	--> La demanda está en proceso de suspensión (ver causa).
			A	ALTA 		--> La demanda está en búsqueda de empleo
			--

		DEM_FEC_INI_SIT_ADM recoge la fecha de inicio de la situación admsinitrativa

		CAU_COD recoge la causa asociada a la situación administrativa según se codifica en VAL_CAU
			select val_val cau_cod, val_des cau_des 
			from VW_SICA_SITA_DEMA_CAUS_INT
			where nvl(val_fec_fin,sysdate+1) > sysdate
			order by 1
			-- Nota de experto: Las causas de situación con valores superiores a 500 son todas las que permiten que 
				una demanda intermedie en ofertas de empleo. Por debajo de ese valor son causas que no permiten esa
				intermediación.

		DEM_FEC_CAU_SIT_ADM fecha en la que se inicia la causa anotada.

		SIT_LAB_COD recoge la situación laboral de la demanda, pero tras consultar con los expertos en gestión de
			empleo, se determina que este valor es en realidad desconocido desde el momento en que una demanda
			cae en baja, ya que deja de actualizarse desde ese momento. Por ello se adapta la extracción con la
			siguiente sentencia DECODE:

			DECODE(SIT_ADM_COD,'B','00',SIT_LAB_COD) SIT_LAB_COD
			
			-- Añadimos por tanto el valor 00 a las posibles situaciones laborales con la descripción DESCONOCIDO
			Este campo toma valores de la tabla VAL_SITLAB
				select '00' slab_cod, 'DESCONOCIDO' slab_des from dual
				UNION
				select val_val slab_cod, val_des slab_des 
				from vw_valores_int where def_cod = 'TCTSITLA'
				and nvl(val_fec_fin,sysdate+1) > sysdate
				order by 1

				00	DESCONOCIDO
				01	OCUPADO 
				02	DESEMPLEADO
				03	TRABAJADOR AGRARIO
				-- Nota del experto: El trabajador agrario se supone una situación asimilada al
					desempleado en términos adminsitrativos.

    	DEM_FEC_INI_SIT_LAB es la fecha de inicio de la situación laboral, pero debido al nuevo valor
    		añadido (00 DESCONOCIDO) debe asumir el valor de la situación administrativa cuando esta es
    		BAJA, por ello el valor se extrae de la siguiente forma:

    		DECODE(SIT_ADM_COD,'B',DEM_FEC_INI_SIT_ADM,DEM_FEC_INI_SIT_LAB) as DEM_FEC_INI_SIT_LAB

		NIV_ACA_COD es, al igual que en PFS, el valor de nivel académico de la demanda. En este caso no
			representa el valor máximo que tiene, sino aquel con el que la persona desea intermediar,
			que puede ser inferior al registrado en PFS.
			Se extrae de la misma forma entonces y toma los valores de VAL_NIV_ACA también.
			decode(niv_aca_cod,'90','00','80','01','32','33','33','32',niv_aca_cod) niv_aca_cod

		ACTI_ECO_COD recoge laúltima actividad económica en la que ha trabajado la perona demandante.
			Nota de la experta: Realmente recoge l actividad económica que figura en su últim contrato.
				El valor analítico de este campo puede ser muy relativo, es una de las cosas que deberíamos
				investigar.
			Toma los valores de la tabla VAL_ACTI_ECO:
				select val_val ACT_COD, val_des ACT_DES
				from vw_valores_int where def_cod = 'TABCCNAE'
				and nvl(val_fec_fin,sysdate+1) > sysdate
				order by 1

		TIENE_PREST es una variable compleja que toma los valores S o N en función de si tiene o no prestación.
			Para ello realizamos la extracción de la sigueinte forma:
		 	DECODE(SIT_ADM_COD, 'B', 'N',
			    CASE WHEN NVL(DEM_FEC_INI_PRE,SYSDATE+1)<SYSDATE THEN 
				    CASE WHEN NVL(DEM_FEC_FIN_PRE,SYSDATE+1)>SYSDATE THEN 'S' 
				    ELSE 'N' END
				ELSE 'N' END) AS TIENE_PREST

		DEM_FEC_INI_PRE recoge el valor de última fecha de inicio de prestación registrada.

		DEM_FEC_FIN_PRE recoge el valor de última fecha de fin de prestación registrada.

		Nota de la experta: Las prestaciones por desempleo actualizan su información en los registros de demanda
			mientras éstas están en alta.

		DUR_PRES duración de la prestación, numérico, en días. Sólo se computa cuando la situación de la demanda 
			es A o S. Por ello se extrae el dato de la siguiente forma:
			DECODE(SIT_ADM_COD, 'B', 0,
				CASE WHEN NVL(DEM_FEC_FIN_PRE,SYSDATE-1)<SYSDATE THEN 0 ELSE
		    		DECODE(DEM_FEC_FIN_PRE-DEM_FEC_INI_PRE,NULL,0,DEM_fEC_FIN_PRE-DEM_FEC_INI_PRE)
		    	END) DUR_PRES

		CCAA_DEM_FEC_UMDC es la fecha en la que la demanda fue modificada por última vez.

		DIAS_SINCAMBIO es un valor numérico que muestra el número de días que ha trasncurrido desde el últim cambio.
			Se extrae mediante la cláusula 
				DECODE(SIT_ADM_COD, 'B', FLOOR(DEM_FEC_INI_SIT_ADM - NVL(CCAA_DEM_FEC_UMDC,DEM_fEC_INS)),
					FLOOR(SYSDATE - NVL(CCAA_DEM_FEC_UMDC,DEM_fEC_INS))) DIAS_SINCAMBIO

		CCAA_DEM_FEC_ULT es la fecha en la que queda registrada la última participación de la demanda
			en una oferta.

		DIAS_SINOFERTA es la cantidad de días en los que la demanda no ha participado en ningún procese
			de candidatura a una oferta de trabajo.
			Se extrae mediante la cláusula
				DECODE(SIT_ADM_COD, 'B', FLOOR(DEM_FEC_INI_SIT_ADM - NVL(CCAA_DEM_FEC_ULT,DEM_FEC_INS)),
						FLOOR(SYSDATE - NVL(CCAA_DEM_FEC_ULT,DEM_FEC_INS))) DIAS_SINOFERTA				

	--> Datos de preferencias registrados en SI_DEMA_G1
		JOR_COD registra el tipo de jornada preferido por la persona demandante. Es un campo obligatorio en el 
			proceso de registro, pero ha documentados errores en el pasado que han dejado algunos registros con
			este campo con un espacio en blanco. Se toma la decisión de excluir los registros afectados añadiendo 
			a la cláusula WHERE el filtro DECODE(JOR_COD, ' ', '99',JOR_COD) < '99'.
			La tabla de alimenta de VAL_JOR_COD:
				select val_val JOR_COD, val_des JOR_DES
				from vw_valores_int where def_cod = 'JORNTRAB'
				and nvl(val_fec_fin,sysdate+1) > sysdate
				order by 1

		DEM_DIS_DOM registra la volunta de la persona de aceptar trabajos a domicilio.
			Adquiere su valor de la tabla VAL_DISDOM:
				select val_val dom_cod, val_Des dom_des from VW_TRAB_DOMI_INT order by 1

		DEM_DIS_AUT_EMP registra la volunta de la persona de aceptar trabajos mediante autoempleo.
			Adquiere su valor de la tabla VAL_AUTEMP:
				select val_val aut_cod, val_Des aut_des from VW_SICA_AUTO_EMPL_INT order by 1

		DEM_DIS_TEL registra la volunta de la persona de aceptar trabajos con teletrabajo.
			Adquiere su valor de la tabla VAL_TELETRAB:
				select val_val tel_cod, val_Des tel_des from VW_SICA_TELE_TRAB_INT order by 1

		DEM_DIS_ETT  registra la volunta de la persona de aceptar trabajos mediante ETT.
			Adquiere su valor de la tabla VAL_ETT:
				select val_val ETT_COD, val_des ETT_DES
				from vw_valores_int where def_cod = 'INDICETT'
				and nvl(val_fec_fin,sysdate+1) > sysdate
				order by 1

		DEM_TUR_NOC registra la volunta de la persona de aceptar trabajos con turno nocturno.
			Adquiere su valor de la tabla VAL_NOCT:
				select val_val NOC_cod, val_Des NOC_des from VW_TURN_ESPE_INT order by 1

		DEM_TUR_FIE registra la volunta de la persona de aceptar trabajos con turno en día festivo.
			Adquiere su valor de la tabla VAL_FEST:
				select val_val fes_cod, val_Des fes_des from VW_TURN_ESPE_FEST_INT order by 1

		DIS_VIA_COD  registra la volunta de la persona de aceptar trabajos que requieran viajar.
			Adquiere su valor de la tabla VAL_VIAJE:
				select val_val VIJ_COD, val_des VIJ_DES
				from vw_valores_int where def_cod = 'DISPVIAJ'
				and nvl(val_fec_fin,sysdate+1) > sysdate
				order by 1

		AMB_BUS_EMP_COD registra el ámbito de búsqueda de empleo en términos geográficos.
			Adqueire valores de la tabla VAL_AMBI:
				select val_val AMB_COD, vafrom vw_valores_int where def_cod = 'AMBBUSDE'
				and nvl(val_fec_fin,sysdate+1) > sysdate
				order by 1
				
			Nota de la experta: Este campo tiene varias particularidades:
				--> Las personas que cobran una prestaicón no pueden registrar ámbitos inferiores al 02.
				--> El valor 12 (ÁMBITO RESTRINGIDO) se refiere a que las personas pueden personalizar
					el ámbito de búsqueda de empleo determinando varias zonas geográficas de granularidad
					diferente además.

			Este 'ámbito restringido' queda recogido en una tabla denominada SI_DEMA_AMBI que se relaciona con
				SI_DEMA_G1 en muchos a 1 (una persona puede registar un número indeterminado de zonas de interés).
				Lo interesante, según la experta, es conocer de todos esos ámbitos, cuál es el de mayor amplitud.

			(!) ¿Sería interesante obtener un histórico de los distintos ámbitos registrados por una persona?

	Como en el caso de la tabla de datos personales, se excluye deliberadamente el conjunto de datos relacioandos con
		mujeres víctimas de violencia de género.
*/