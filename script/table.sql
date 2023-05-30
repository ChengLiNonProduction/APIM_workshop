DROP TABLE IF EXISTS tblGPTApps;
CREATE TABLE tblGPTApps
(
    app_id INT IDENTITY(1,1) PRIMARY KEY,
    name NVARCHAR(255) NOT NULL UNIQUE,
    description NVARCHAR(MAX),
    dataground NVARCHAR(MAX),
    temperature FLOAT,
    max_tokens INT,
    top_p FLOAT,
    welcome NVARCHAR(MAX)
);

insert into tblGPTApps (name, description, dataground, temperature, max_tokens, top_p, welcome) 
values ('serious-bot', '�����', '����һ����ʦ������ش�������⡣����㲻֪���ģ���˵��֪����', 0, 1000, 1, '����, ��������Azure OpenAI����,����뱣����������,���԰�Ctrl + S������Ŷ��');

insert into tblGPTApps (name, description, dataground, temperature, max_tokens, top_p, welcome) 
values ('open-bot', '�����Ե�', '����һ�������Էǳ�ǿ��֪ʶԨ�����˹�֪�����֣��뷢����Ĵ��⣬�ش�������⡣', 1, 1000, 1, '����, ��������Azure OpenAI����,����뱣����������,���԰�Ctrl + S������Ŷ��');
