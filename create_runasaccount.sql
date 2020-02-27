INSERT INTO 
						`accounts`
						(
							accountName,
							userName,
							password,
							domain,
							accountType
						)
						VALUES
						(
							'TestAccount',
							HEX(AES_ENCRYPT('<Account Name here>', 'pN\Å\ãmø´\Òÿ\ï0\0T2.\á·{«Ø¥\ÜÐ™û{5Fµ')),
							HEX(AES_ENCRYPT('<Account Password here>', 'pN\Å\ãmø´\Òÿ\ï0\0T2.\á·{«Ø¥\ÜÐ™û{5Fµ')),
							IF('' = '', '',  HEX(AES_ENCRYPT('', 'pN\Å\ãmø´\Òÿ\ï0\0T2.\á·{«Ø¥\ÜÐ™û{5Fµ'))),
							''
						)
