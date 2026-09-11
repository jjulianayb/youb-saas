\set ON_ERROR_STOP on
begin;
insert into public.organizations(id,name,slug,plan,status) values
 ('dddddddd-dddd-dddd-dddd-dddddddddddd','Demo V1 Organization','demo-v1-organization','essencial','active'),
 ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee','Adversarial Organization','adversarial-organization','essencial','active');
insert into public.memberships(organization_id,user_id,role) values
 ('dddddddd-dddd-dddd-dddd-dddddddddddd', :'ADMIN_ID','admin_youb'),
 ('dddddddd-dddd-dddd-dddd-dddddddddddd', :'RH_ID','rh'),
 ('dddddddd-dddd-dddd-dddd-dddddddddddd', :'DIRETORIA_ID','diretoria'),
 ('dddddddd-dddd-dddd-dddd-dddddddddddd', :'GESTOR_ID','gestor'),
 ('dddddddd-dddd-dddd-dddd-dddddddddddd', :'COLABORADOR_ID','colaborador'),
 ('dddddddd-dddd-dddd-dddd-dddddddddddd', :'NOEMP_ID','colaborador'),
 ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', :'TENANT_B_ID','colaborador');
insert into public.areas(id,organization_id,name) values
 ('dddddddd-0000-0000-0000-000000000001','dddddddd-dddd-dddd-dddd-dddddddddddd','Produto'),
 ('eeeeeeee-0000-0000-0000-000000000001','eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee','Adversarial');
insert into public.positions(id,organization_id,name,level) values
 ('dddddddd-0000-0000-0000-000000000002','dddddddd-dddd-dddd-dddd-dddddddddddd','Gestor V1','pleno'),
 ('dddddddd-0000-0000-0000-000000000003','dddddddd-dddd-dddd-dddd-dddddddddddd','Colaborador V1','junior'),
 ('eeeeeeee-0000-0000-0000-000000000002','eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee','Posição B','pleno');
insert into public.employees(id,organization_id,auth_user_id,full_name,email,area_id,position_id,status,manager_employee_id) values
 ('dddddddd-0000-0000-0000-000000000010','dddddddd-dddd-dddd-dddd-dddddddddddd',:'GESTOR_ID','Gestor Demo','gestor@demo.invalid','dddddddd-0000-0000-0000-000000000001','dddddddd-0000-0000-0000-000000000002','active',null),
 ('dddddddd-0000-0000-0000-000000000011','dddddddd-dddd-dddd-dddd-dddddddddddd',:'COLABORADOR_ID','Colaborador Demo','colaborador@demo.invalid','dddddddd-0000-0000-0000-000000000001','dddddddd-0000-0000-0000-000000000003','active','dddddddd-0000-0000-0000-000000000010'),
 ('eeeeeeee-0000-0000-0000-000000000010','eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',:'TENANT_B_ID','Tenant B User','tenant-b@demo.invalid','eeeeeeee-0000-0000-0000-000000000001','eeeeeeee-0000-0000-0000-000000000002','active',null);
insert into public.competencies(id,organization_id,name,description) values
 ('dddddddd-0000-0000-0000-000000000020','dddddddd-dddd-dddd-dddd-dddddddddddd','Colaboração','Fictícia V1'),
 ('dddddddd-0000-0000-0000-000000000021','dddddddd-dddd-dddd-dddd-dddddddddddd','Entrega','Fictícia V1');
insert into public.position_competencies(id,organization_id,position_id,competency_id,expected_level) values
 ('dddddddd-0000-0000-0000-000000000030','dddddddd-dddd-dddd-dddd-dddddddddddd','dddddddd-0000-0000-0000-000000000003','dddddddd-0000-0000-0000-000000000020',3),
 ('dddddddd-0000-0000-0000-000000000031','dddddddd-dddd-dddd-dddd-dddddddddddd','dddddddd-0000-0000-0000-000000000003','dddddddd-0000-0000-0000-000000000021',4);
insert into public.cycles(id,organization_id,name,cycle_type,starts_at,ends_at,status) values
 ('dddddddd-0000-0000-0000-000000000040','dddddddd-dddd-dddd-dddd-dddddddddddd','Ciclo Commercial V1','performance','2026-01-01','2026-12-31','active');
insert into public.assessments(id,organization_id,cycle_id,subject_employee_id,evaluator_employee_id,scores,status) values
 ('dddddddd-0000-0000-0000-000000000050','dddddddd-dddd-dddd-dddd-dddddddddddd','dddddddd-0000-0000-0000-000000000040','dddddddd-0000-0000-0000-000000000011','dddddddd-0000-0000-0000-000000000010','{"dddddddd-0000-0000-0000-000000000020":4,"dddddddd-0000-0000-0000-000000000021":3}','draft');
insert into public.pdis(id,organization_id,employee_id,cycle_id,objective,actions,status,due_date) values
 ('dddddddd-0000-0000-0000-000000000060','dddddddd-dddd-dddd-dddd-dddddddddddd','dddddddd-0000-0000-0000-000000000011','dddddddd-0000-0000-0000-000000000040','Evoluir colaboração com segurança','[{"title":"Prática fictícia","status":"planned"}]','draft','2026-12-31');
insert into public.checkins(organization_id,employee_id,checkin_date,mood,engagement,energy,workload,note,created_by) values
 ('dddddddd-dddd-dddd-dddd-dddddddddddd','dddddddd-0000-0000-0000-000000000011','2026-09-10',4,4,4,3,'Check-in fictício',:'COLABORADOR_ID');
commit;
